resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf build && mkdir build
      cp -r lambdas/* build/
      pip install -r lambdas/requirements.txt -t build/
    EOT
  }

  triggers = {
    requirements_hash = filesha1("lambdas/requirements.txt")
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build"
  output_path = "${path.module}/build.zip"

  depends_on = [null_resource.install_dependencies]
}

data "aws_ssm_parameter" "admin_sns_topic" {
  name = "/backend/sns/admin_topic"
}

# RESOURCES

resource "aws_lambda_function" "ingestion_lambda" {
  function_name = "${var.project_part}-ingestion-lambda"
  description   = "This lambda will get data from api and store it in S3 bucket."

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "ingestion_lambda.lambda_handler"
  runtime          = "python3.9"
  timeout          = 300

  role       = aws_iam_role.lambda_role.arn
  depends_on = [null_resource.install_dependencies]

}

# ROLES

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_part}-ingestion-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "lambda.amazonaws.com"
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda-policy" {
  name = "${var.project_part}-ingestion-lambda-role-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "codebuild:*",
          "logs:*",
          "sns:*",
          "ssm:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ALARMS

resource "aws_cloudwatch_metric_alarm" "ingestion_lambda_errors" {
  alarm_name          = "${aws_lambda_function.ingestion_lambda.function_name}-failed-alarm"
  alarm_description   = "Trigger an alarm when the Errors metric is greater than 0"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  evaluation_periods  = 1
  period              = 60
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.ingestion_lambda.function_name
  }

  alarm_actions = [
    data.aws_ssm_parameter.admin_sns_topic.value
  ]
}
