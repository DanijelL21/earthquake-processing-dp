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
  default     = "terraform-ingestion"
}

variable "api_url" {
  description = "The earthquake api url"
  type        = string
  default     = "https://earthquake.usgs.gov/fdsnws/event/1"
}

variable "dest_table_name" {
  description = "Name of the destionation table"
  type        = string
  default     = "earthquake_data"
}
