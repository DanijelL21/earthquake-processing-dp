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

variable "project_part" {
  description = "The name of the project part"
  type        = string
  default     = "earthquake-processing"
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
