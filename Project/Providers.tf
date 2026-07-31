terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.56.0"
    }
  }

  backend "s3" {}
  #backend "s3" {
  # bucket = "sunkersss4-dev"
  #  key    = "terraform.tfstate"
  #  region = "af-south-1"
  #  encrypt = true
  #  use_lockfile = true
 # }
  required_version = "~>1.15"
}