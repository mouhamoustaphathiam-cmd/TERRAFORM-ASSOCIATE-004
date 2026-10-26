provider "aws" {
  region = "us-east-1"
}

data "aws_region" "region_aws" {

}

data "aws_caller_identity" "aws_id" {

}

resource "aws_s3_bucket" "stockage_data" {
  bucket = "tp04-${data.aws_caller_identity.aws_id.account_id}-${data.aws_region.region_aws.region}"

  tags = {
    Name : "tp04-data"
    Region : data.aws_region.region_aws.region
    Owner : data.aws_caller_identity.aws_id.account_id

  }
}
data "aws_s3_bucket" "hands_bucket_create" {
  bucket = "tp04-datasources"
}