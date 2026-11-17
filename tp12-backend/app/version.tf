terraform {
  required_version = ">=1.12"
  required_providers {
    aws ={
    source = "hashicorp/aws"
    version = "~>6.0"
    }
  }
  backend "s3" {
    bucket = "mmt-tfstate-distant"
    key = "tp12-backend/app/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    use_lockfile = true
  }
}

resource "aws_s3_bucket" "tp12-backend" {
  bucket = "mmt-tp12-app"
  
}

