variable "nom_bucket" {
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.nom_bucket))
    error_message = "nom du compartiment invalide verifiez votre saisie"
  }
}