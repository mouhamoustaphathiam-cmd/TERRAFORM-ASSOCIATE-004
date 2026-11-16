provider "aws" {
  region = "us-east-1"
}

resource "aws_ssm_parameter" "mdp_bd" {
  name             = "/tp09/bd_pwd"
  type             = "SecureString"
  value_wo         = var.db_pwd
  value_wo_version = 1
}