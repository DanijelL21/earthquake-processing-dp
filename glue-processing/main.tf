data "aws_ssm_parameter" "source_bucket" {
  name = "/backend/databucket"
}

data "aws_ssm_parameter" "s3_artifact_bucket" {
  name = "/backend/s3_artifact_bucket"
}

data "aws_ssm_parameter" "source_table_name" {
  name = "/s3/table_name"
}

data "aws_ssm_parameter" "admin_sns_topic" {
  name = "/backend/sns/admin_topic"
}

# Upload the script to S3 from a local directory
resource "aws_s3_object" "glue_jobs_scripts" {
  for_each = fileset("scripts/", "*")

  bucket = data.aws_ssm_parameter.s3_artifact_bucket.value
  key    = "glue-jobs/${each.value}"
  source = "scripts/${each.value}"
}


# RESOURCES

resource "aws_glue_workflow" "processing_workflow" {
  name = "${var.project_part}-workflow"
}

resource "aws_glue_trigger" "source_table_crawler_trigger" {
  name              = "${var.project_part}-SourceTableCrawlerTrigger"
  type              = "SCHEDULED"
  schedule          = "cron(0 10 * * ? *)"
  start_on_creation = true
  workflow_name     = aws_glue_workflow.processing_workflow.name

  actions {
    crawler_name = aws_glue_crawler.source_table_crawler.name
  }
}

resource "aws_glue_crawler" "source_table_crawler" {
  name          = "${var.project_part}-SourceTableCrawler"
  database_name = var.source_database
  role          = aws_iam_role.glue_role.arn

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DELETE_FROM_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  s3_target {
    path = "s3://${data.aws_ssm_parameter.source_bucket.value}/${data.aws_ssm_parameter.source_table_name.value}/"
  }
}

resource "aws_glue_trigger" "processing_job_trigger" {
  name              = "${var.project_part}-GlueJobTrigger"
  type              = "CONDITIONAL"
  start_on_creation = true
  workflow_name     = aws_glue_workflow.processing_workflow.name

  actions {
    job_name = aws_glue_job.processing_job.name
  }

  predicate {
    conditions {
      crawler_name     = aws_glue_crawler.source_table_crawler_trigger.name
      crawl_state      = "SUCCEEDED"
      logical_operator = "EQUALS"
    }
  }
}

resource "aws_glue_job" "processing_job" {
  name         = "${var.project_part}-glue-job"
  glue_version = "3.0"
  role_arn     = aws_iam_role.glue_role.arn
  max_retries  = 3

  command {
    name            = "glueetl"
    script_location = "s3://${data.aws_ssm_parameter.s3_artifact_bucket.value}/glue-jobs/processing-job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--JobName"            = "${var.project_part}-glue-job"
    "--SourceDatabaseName" = var.source_database
    "--SourceTableName"    = data.aws_ssm_parameter.source_table_name.value
    "--DestTableName"      = var.sf_table_name
    "--SecretName"         = var.sf_secret_name
    "--SFDatabase"         = var.sf_db_name
    "--SFSchema"           = var.sf_schema_name
  }

  execution_property {
    max_concurrent_runs = 1
  }

  worker_type = "G.1X"

  number_of_workers = 10

  max_capacity = 10
}

resource "aws_glue_trigger" "processing_job_trigger" {
  name              = "${var.project_part}-FailGlueJobTrigger"
  type              = "CONDITIONAL"
  start_on_creation = true
  workflow_name     = aws_glue_workflow.processing_workflow.name

  actions {
    job_name = aws_glue_job.processing_job_alarm.name
  }

  predicate {
    conditions {
      job_name         = aws_glue_job.processing_job.name
      state            = "FAILED"
      logical_operator = "EQUALS"
    }
  }
}

resource "aws_glue_job" "processing_job_alarm" {
  name         = "${var.project_part}-glue-job-fail-alarm"
  glue_version = "3.0"
  role_arn     = aws_iam_role.glue_role.arn
  max_retries  = 3

  command {
    name            = "pythonshell"
    script_location = "s3://${data.aws_ssm_parameter.s3_artifact_bucket.value}/glue-jobs/processing-job-fail-alarm.py"
    python_version  = "3"
  }

  default_arguments = {
    "--JobName"    = "${var.project_part}-glue-job-fail-alarm"
    "--AlarmTopic" = data.aws_ssm_parameter.admin_sns_topic.value
  }

}


# ROLES

resource "aws_iam_role" "glue_role" {
  name = "${var.project_part}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "glue.amazonaws.com"
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "glue_policy" {
  name = "${var.project_part}-glue-role-policy"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*" # MODIFY
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

# ALARMS

resource "aws_cloudwatch_event_rule" "crawlers_fail_alarm" {
  name        = "${aws_glue_crawler.source_table_crawler.name}-FailAlarm"
  description = "Triggers an alarm when crawler fails"
  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail_type = ["Glue Crawler State Change"]
    detail = {
      state       = ["Failed"]
      crawlerName = aws_glue_crawler.source_table_crawler.name
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.crawlers_fail_alarm.name
  target_id = "SendToSNS"
  arn       = data.aws_ssm_parameter.admin_sns_topic.value
}
