provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tp-terraform" {
  bucket     = "tp07-mmt-app-v2-2"
  depends_on = [aws_s3_bucket.tp07-terraform]
  lifecycle {
    create_before_destroy = true
    #ignore_changes = [tags]
  }
  tags = {
    equipe = "finance"  
  }

}

resource "aws_s3_bucket" "tp07-terraform" {
  bucket = "tp07-mmt-logs"
  lifecycle {
   # prevent_destroy = true
  }

}
