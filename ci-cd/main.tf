locals {
  github_config = jsondecode(file("github_config.json"))
}

locals {
  production_mode = var.environment == "prod"
}

data "aws_ssm_parameter" "s3_artifact_bucket" {
  name = "/backend/s3_artifact_bucket"
}

data "aws_ssm_parameter" "admin_sns_topic" {
  name = "/backend/sns/admin_topic"
}

# RESOURCES

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.project_part}-cicd"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = data.aws_ssm_parameter.s3_artifact_bucket.value
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["PipelineSourceArtifacts"]

      configuration = {
        Owner      = local.github_config.github_owner
        Repo       = local.github_config.github_repo
        Branch     = local.github_config.github_branch
        OAuthToken = local.github_config.github_oauth_token
      }
    }
  }

  stage {
    name = "Test"

    action {
      name             = "CodeBuild_Test"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["PipelineSourceArtifacts"]
      output_artifacts = ["PipelineTestArtifacts"]

      configuration = {
        ProjectName = aws_codebuild_project.testing_project.name
      }
    }
  }

  dynamic "stage" {
    for_each = local.production_mode ? [1] : []

    content {
      name = "Approve"

      action {
        name     = "Production-Approval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
        configuration = {
          NotificationArn = data.aws_ssm_parameter.admin_sns_topic.value
        }
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "CodeBuild_Deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["PipelineSourceArtifacts"]
      output_artifacts = ["PipelineDeployArtifacts"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy_project.name
      }
    }
  }
}

# PROJECTS

resource "aws_codebuild_project" "testing_project" {
  name         = "${var.project_part}-cicd-test"
  service_role = aws_iam_role.codepipeline_role.arn

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "ci-cd/buildspec-testing.yml"
  }
}

resource "aws_codebuild_project" "deploy_project" {
  name         = "${var.project_part}-deploy"
  service_role = aws_iam_role.codepipeline_role.arn

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
      type  = "PLAINTEXT"
    }
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type     = "CODEPIPELINE"
    location = "ci-cd/buildspec.yml"
  }
}

# ROLES

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_part}-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "codepipeline.amazonaws.com",
          "codebuild.amazonaws.com"
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_part}-cicd-role-policy"
  role = aws_iam_role.codepipeline_role.id
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

resource "aws_cloudwatch_event_rule" "codepipeline_notifications" {
  name = "${var.project_part}-ci-cd-notifications"

  event_pattern = jsonencode({
    "detail-type" = ["CodePipeline Stage Execution State Change"],
    "source"      = ["aws.codepipeline"],
    "detail" = {
      "pipeline" = [aws_codepipeline.codepipeline.name]
      "state"    = ["FAILED", "CANCELED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "notifications_target" {
  rule      = aws_cloudwatch_event_rule.codepipeline_notifications.name
  arn       = data.aws_ssm_parameter.admin_sns_topic.value
  target_id = "TargetTopic"
}
