variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile for local deployment."
  type        = string
}

variable "project_part" {
  description = "The name of the project part"
  type        = string
  default     = "earthquake-processing"
}

variable "admin_emails" {
  type    = list(string)
  default = ["leonidanijel@gmail.com"]
}
