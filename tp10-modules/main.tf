provider "aws" {
  region = "us-east-1"
}

module "app" {
  source = "./modules/bucket"
  env    = "environnement"
  nom    = "mmt-tp10-app"
  tags   = { LogsBucket = module.logs.nom_bucket }
}
module "logs" {
  source = "./modules/bucket"
  env    = "environnement"
  nom    = "mmt-tp10-logs"
}

module "archives" {
  bucket  = "mmt-archives-hasicorp"
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"
  versioning = {
    enable = true
  }
}
