resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf build && mkdir build
      cp -r lambdas/* build/
      pip install -r lambdas/requirements.txt -t build/
    EOT
  }

  triggers = {
    always_run = timestamp()
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

  filename = data.archive_file.lambda_zip.output_path
  handler  = "ingestion_lambda.lambda_handler"
  runtime  = "python3.9"
  timeout  = 300

  role       = aws_iam_role.lambda_role.arn
  depends_on = [null_resource.install_dependencies]

}

resource "aws_lambda_function_event_invoke_config" "ingestion_lambda_retry" {
  function_name                = aws_lambda_function.ingestion_lambda.function_name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 3
}

resource "aws_cloudwatch_event_rule" "ingestion_lambda_trigger" {
  name                = "${aws_lambda_function.ingestion_lambda.function_name}-hourly-trigger"
  description         = "Trigger Ingestion Lambda every hour"
  schedule_expression = "rate(1 hour)"
  state               = "DISABLED"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.ingestion_lambda_trigger.name
  target_id = "lambda"
  arn       = aws_lambda_function.ingestion_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ingestion_lambda_trigger.arn
}

# ROLES

resource "aws_iam_role" "lambda_role" {
  name = "${aws_lambda_function.ingestion_lambda.function_name}-role"

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
  name = "${aws_lambda_function.ingestion_lambda.function_name}-role-policy"
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
