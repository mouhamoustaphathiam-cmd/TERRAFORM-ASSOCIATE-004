provider "aws" {
  region = "us-east-1"
  alias  = "env_deploy"
}

provider "aws" {
  region = "eu-west-3"
}

resource "aws_s3_bucket" "stockage1" {
  bucket   = "tp03-alias"
  provider = aws.env_deploy
}
resource "aws_s3_bucket" "stockage2" {
  bucket = "tp03-noalias"
}
