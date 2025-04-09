resource "aws_s3_bucket" "s3_data_bucket" {
  bucket_prefix = "${var.project_part}-databucket-"

  tags = {
    SERVICE = var.project_part
  }
}

resource "aws_ssm_parameter" "s3_data_bucket_name" {
  name  = "/backend/databucket"
  type  = "String"
  value = aws_s3_bucket.s3_data_bucket.id
}
