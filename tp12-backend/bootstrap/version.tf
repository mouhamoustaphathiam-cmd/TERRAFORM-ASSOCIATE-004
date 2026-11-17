terraform {
  required_version = ">=1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "state_backend" {
  bucket = "mmt-tfstate-distant"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "backend_state" {
  bucket = aws_s3_bucket.state_backend.id
  versioning_configuration {
  
    status = "Enabled"
  }
  lifecycle {
    prevent_destroy = true
  }
}