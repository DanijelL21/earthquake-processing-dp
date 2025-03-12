provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_s3_bucket" "s3_backend" {
  bucket_prefix = "${var.project_part}-"

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
  bucket_prefix = "${var.project_part}-artifactbucket"

  tags = {
    SERVICE = var.project_part
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifact_bucket_lifecycle" {
  bucket = aws_s3_bucket.artifact_bucket.id

  rule {
    id     = "expire_old_objects"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1
    }
  }
}

resource "aws_ssm_parameter" "artifact_bucket_name" {
  name  = "/backend/s3_artifact_bucket"
  type  = "String"
  value = aws_s3_bucket.artifact_bucket.id
}
