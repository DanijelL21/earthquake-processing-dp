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
