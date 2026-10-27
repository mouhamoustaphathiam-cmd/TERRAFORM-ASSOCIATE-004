provider "aws" {
  region = var.region_auto[0]
}
resource "aws_s3_bucket" "stockage_s3" {
  bucket = "${var.environment}-${var.project}-${var.compt_config.suffix}"
  tags = var.balise
  force_destroy = var.compt_config.force_destroy
}
