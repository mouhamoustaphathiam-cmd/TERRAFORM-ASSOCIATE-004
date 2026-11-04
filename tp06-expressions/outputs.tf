output "bucket_arn" {
  value = { for key, bucket in aws_s3_bucket.nmbr-compt : key => bucket.arn }

}