provider "aws" {
  region = "us-east-1"
}
resource "aws_s3_bucket" "lab_tp001" {
  bucket = "bucket-tp001-mmt"
  tags = {
    Name = "Bucket-Tp001"
    Environment  = "Dev"
  }
}