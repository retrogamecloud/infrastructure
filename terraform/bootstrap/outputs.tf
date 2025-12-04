output "terraform_state_bucket" {
  description = "Nombre del bucket S3 para el estado de Terraform"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_lock_table" {
  description = "Nombre de la tabla DynamoDB para locks"
  value       = aws_dynamodb_table.terraform_lock.id
}

output "aws_region" {
  description = "Región de AWS donde se crearon los recursos"
  value       = var.aws_region
}

# =============================================================================
# OUTPUTS DE ROUTE53
# =============================================================================

output "route53_zone_id" {
  description = "ID de la Hosted Zone de Route53"
  value       = aws_route53_zone.main.zone_id
}

output "route53_nameservers" {
  description = "Nameservers de Route53 para configurar en el registrador"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "Nombre de dominio configurado"
  value       = var.domain_name
}

# =============================================================================
# OUTPUTS DE USUARIOS IAM
# =============================================================================

# output "iam_users_created" {
#   description = "Lista de usuarios IAM creados"
#   value       = keys(aws_iam_user.users)
# }

# output "user_passwords" {
#   description = "Contraseñas generadas para los usuarios (solo visible con terraform output -json)"
#   value = {
#     for user in var.admin_users : user => aws_iam_user_login_profile.user_passwords[user].password
#   }
#   sensitive = true
# }

# output "user_access_keys" {
#   description = "Access Keys de los usuarios (solo visible con terraform output -json)"
#   value = {
#     for user in var.admin_users : user => {
#       access_key_id     = aws_iam_access_key.keys[user].id
#       secret_access_key = aws_iam_access_key.keys[user].secret
#     }
#   }
#   sensitive = true
# }

# =============================================================================
# INSTRUCCIONES
# =============================================================================

output "next_steps" {
  description = "Instrucciones para usar este backend en otros proyectos Terraform"
  value       = <<-EOT
  
  ✅ Infraestructura de backend creada exitosamente!
  
  👥 Usuarios IAM creados: ${join(", ", keys(aws_iam_user.users))}
  
  📝 Para obtener las credenciales de los usuarios:
     terraform output -json user_passwords
     terraform output -json user_access_keys
  
  📝 Para usar este backend en tus proyectos Terraform (ej: eks_test):
  
  1. Actualiza el backend en provider.tf:
     backend "s3" {
       bucket         = "${aws_s3_bucket.terraform_state.id}"
       key            = "eks/terraform.tfstate"  # Cambia según el proyecto
       region         = "${var.aws_region}"
       dynamodb_table = "${aws_dynamodb_table.terraform_lock.id}"
       encrypt        = true
       profile        = "${var.aws_profile}"
     }
  
  2. Inicializa el backend:
     terraform init
  
  EOT
}
