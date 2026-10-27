variable "aws_region" {
  description = "Region du provider"
  type        = string
  default     = "us-east-1"
}
variable "environment" {
  description = "Environnement de deploiement"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Projet de deploiement S3"
  type        = string
}
variable "balise" {
  description = "Balisages"
  type        = map(string)
  default = {
    Owner   = "mmt"
    Project = "Deploi-TF"
  }
}
variable "region_auto" {
  description = "les regions autorisees"
  type        = list(string)
  default     = ["us-east-1", "eu-west-1"]
}
variable "compt_config" {
  description = "configuration du compartiment"
  type = object({
    suffix        = string
    force_destroy = bool
  })
  default = {
    suffix        = "mmt"
    force_destroy = false
  }
}
