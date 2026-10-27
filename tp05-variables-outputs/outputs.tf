output "aws_s3_bucket" {
  description = "Nom du compartiment S3"
  value       = aws_s3_bucket.stockage_s3.bucket
}

output "aws_s3_bucket_arn" {
  description = "ARN du compartiment S3"
  value       = aws_s3_bucket.stockage_s3.arn
}