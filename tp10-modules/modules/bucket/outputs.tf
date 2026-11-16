output "nom_bucket" {
    description = "Nom du compartiment"
  value = aws_s3_bucket.bucket-tp-modules.id
}

output "arn" {
    description = "ARN du compartiment"
  value = aws_s3_bucket.bucket-tp-modules.arn
}