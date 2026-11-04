variable "region_aws" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"

}

variable "noms_bucket" {
  description = "nom des compartiments"
  type        = map(string)
  default = {
    donnees    = "data"
    journal    = "logs"
    sauvegarde = "backup"
  }
}
locals {
  tags_communs = {
    Project = "tp06"
    Owner   = "mmt"
  }
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "regles_expiration" {
  description = "Regles d'expiration des donnees "
  type        = map(number)
  default = {
    app  = 30
    temp = 7
    archives = 365
  }

}
