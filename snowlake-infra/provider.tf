locals {
  snoflake_config = jsondecode(file("snoflake_config.json"))
}

terraform {
  required_providers {
    snowflake = {
      source = "Snowflake-Labs/snowflake"
    }
  }
}

provider "snowflake" {
  organization_name        = local.snoflake_config.organization_name
  account_name             = local.snoflake_config.account_name
  user                     = local.snoflake_config.user
  password                 = local.snoflake_config.password # This should be secrets manager or similar
  preview_features_enabled = ["snowflake_table_resource"]
}

terraform {
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
