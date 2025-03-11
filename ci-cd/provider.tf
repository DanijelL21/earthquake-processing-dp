provider "aws" {
  region  = var.region
  profile = var.profile
}

terraform {
  backend "s3" {
    key          = "addenv/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
