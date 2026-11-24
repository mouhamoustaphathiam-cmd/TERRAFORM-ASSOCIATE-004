resource "aws_s3_bucket" "tp13-state" {
  bucket = "mmt-tp13-drift"
  tags = {
    Environment = "prod"
  }
}

import {
  to = aws_s3_bucket.tp13-state
  id = "tp13-mmt-drift"
}