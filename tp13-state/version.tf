terraform {
  required_version = ">=1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }

  backend "s3" {
    bucket       = "mmt-tfstate-distant"
    key          = "tp13-state/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
