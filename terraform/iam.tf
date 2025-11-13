# Grupo de administradores
resource "aws_iam_group" "admins" {
  name = "Administrators"
}

# Política de acceso total al grupo
resource "aws_iam_group_policy_attachment" "admin_policy" {
  group      = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Crear usuarios
resource "aws_iam_user" "users" {
  for_each      = toset(var.admin_users)
  name          = each.key
  force_destroy = true
}

# Asignar los usuarios al grupo de administradores
resource "aws_iam_user_group_membership" "admin_membership" {
  for_each = toset(var.admin_users)
  user     = aws_iam_user.users[each.key].name
  groups   = [aws_iam_group.admins.name]
}

# Crear claves de acceso para cada usuario
resource "aws_iam_access_key" "keys" {
  for_each = toset(var.admin_users)
  user     = aws_iam_user.users[each.key].name
}

# Configurar contraseñas para acceso a la consola
resource "aws_iam_user_login_profile" "user_passwords" {
  for_each                = toset(var.admin_users)
  user                    = aws_iam_user.users[each.key].name
  password_length         = 32 
  password_reset_required = true

  lifecycle {
    ignore_changes = [password_reset_required]
  }
}

# Outputs para mostrar las contraseñas generadas
output "user_passwords" {
  description = "Contraseñas generadas para los usuarios"
  value = {
    for user in var.admin_users : user => aws_iam_user_login_profile.user_passwords[user].password
  }
  sensitive = true
}