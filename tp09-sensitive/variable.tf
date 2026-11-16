variable "db_pwd" {
  type      = string
  sensitive = true
  ephemeral = true
}