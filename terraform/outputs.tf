output "iam_user_names" {
  description = "Lista de usuarios IAM creados"
  value       = [for user in aws_iam_user.users : user.name]
}

output "access_keys" {
  description = "Access key IDs de los usuarios"
  value       = { for k, v in aws_iam_access_key.keys : k => v.id }
  sensitive   = true
}