provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_s3_bucket" "s3_backend" {
  bucket_prefix = "${var.project_part}-backendbucket-"

  tags = {
    SERVICE = var.project_part
  }
}

resource "aws_ssm_parameter" "s3_bucket_name" {
  name  = "/backend/s3_bucket"
  type  = "String"
  value = aws_s3_bucket.s3_backend.id
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket_prefix = "${var.project_part}-artifactbucket-"

  tags = {
    SERVICE = var.project_part
  }
}

resource "aws_ssm_parameter" "artifact_bucket_name" {
  name  = "/backend/s3_artifact_bucket"
  type  = "String"
  value = aws_s3_bucket.artifact_bucket.id
}

resource "aws_sns_topic" "admin_sns_topic" {
  name = "${var.project_part}-admin-topic"
}

resource "aws_ssm_parameter" "admin_sns_topic_arn" {
  name  = "/backend/sns/admin_topic"
  type  = "String"
  value = aws_sns_topic.admin_sns_topic.arn
}

resource "aws_sns_topic_subscription" "admin_sns_topic_subscription" {
  for_each  = toset(var.admin_emails)
  topic_arn = aws_sns_topic.admin_sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}
