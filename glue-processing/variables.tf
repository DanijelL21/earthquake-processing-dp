variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile for local deployment."
  type        = string
  default     = ""
}

variable "environment" {
  description = "The environment to deploy resources"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "preprod", "prod"], var.environment)
    error_message = "The environment must be one of 'dev', 'staging', or 'prod'."
  }
}

variable "project_part" {
  description = "The name of the project part"
  type        = string
  default     = "terraform-processing"
}

variable "source_database" {
  description = "Source database name"
  type        = string
  default     = "events"
}

variable "sf_secret_name" {
  description = "Name of the secret stored in AWS secret manager"
  type        = string
}

variable "sf_db_name" {
  description = "Name of snoflake database"
  type        = string
}

variable "sf_table_name" {
  description = "Name of snoflake table"
  type        = string
}

variable "sf_schema_name" {
  description = "Name of snoflake schema"
  type        = string
}
