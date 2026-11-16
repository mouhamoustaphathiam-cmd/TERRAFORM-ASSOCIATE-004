resource "aws_s3_bucket" "bucket-tp-modules" {
  bucket = "${var.nom}-${var.env}"
  tags = merge({environnement = var.env}, var.tags)
}