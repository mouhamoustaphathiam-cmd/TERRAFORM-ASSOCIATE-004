provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "stockage_s3" {
  bucket = "tp02-${random_pet.stockage.id}"

}

resource "random_pet" "stockage" {
    length = 4
}