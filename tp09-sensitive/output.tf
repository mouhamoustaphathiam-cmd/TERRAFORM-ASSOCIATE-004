output "mot_de_passe" {
  value     = aws_ssm_parameter.mdp_bd
  sensitive = true
}