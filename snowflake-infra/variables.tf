variable "environment" {
  description = "The environment to deploy resources"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "preprod", "prod"], var.environment)
    error_message = "The environment must be one of 'dev', 'staging', or 'prod'."
  }
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
