terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.36"
    }
  }

  backend "s3" {
    bucket = "fiap-3soat-g15-iac-auth"
    key    = "live/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}
