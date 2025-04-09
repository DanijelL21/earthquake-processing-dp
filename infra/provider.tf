provider "aws" {
  region  = var.region
  profile = var.profile
}

terraform {
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
