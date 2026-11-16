provider "aws" {
  region = "us-east-1"
}

data "aws_region" "verif_region" {
  
}
resource "aws_s3_bucket" "nom_bucket" {
  bucket = var.nom_bucket
  lifecycle {
    precondition {
      condition = data.aws_region.verif_region.region == "us-east-1"
      error_message = "Verifiez la region du deploiement"
    }
    postcondition {
      condition = self.bucket_region == data.aws_region.verif_region.region
      error_message = "Le bucket ne se trouve pas dans la region declare"
    }
  }

}
check "conv_nommage" {
  assert {
    condition = startswith(aws_s3_bucket.nom_bucket.bucket , "-tp08")
    error_message = "Verifier la convention de nommage de l equipe"
  }
}