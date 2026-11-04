provider "aws" {
  region = var.region_aws
}

resource "aws_s3_bucket" "nmbr-compt" {
  # count  = length(var.noms_bucket)
  # bucket = "tp06-mmt-bucket-${var.noms_bucket[count.index]}"
  for_each = var.noms_bucket
  bucket   = "tp06-mmt-bucket-${each.value}"
  tags     = merge(local.tags_communs, { Name = each.value })

  force_destroy = var.environment == "dev" ? true : false
}
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.nmbr-compt["journal"].id
  dynamic "rule" {
    for_each = var.regles_expiration
    content {
      id     = rule.key
      status = "Enabled"
      filter {
        prefix = "${rule.key}/"
      }
      expiration {
        days = rule.value
      }
    }
  }
}