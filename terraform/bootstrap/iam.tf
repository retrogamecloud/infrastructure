# =============================================================================
# GESTIÓN DE USUARIOS IAM
# =============================================================================
# Este archivo crea usuarios IAM con permisos de administrador

# Grupo de administradores
resource "aws_iam_group" "admins" {
  name = "Administrators"
}

# Política de acceso total al grupo
resource "aws_iam_group_policy_attachment" "admin_policy" {
  group      = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============================================================================
# USUARIO TERRAFORM (PROTEGIDO PERMANENTEMENTE)
# ============================================================================

resource "aws_iam_user" "terraform_user" {
  name          = "retrogamecloud-terraform"
  force_destroy = false

  tags = {
    Role      = "Terraform Administrator"
    ManagedBy = "Terraform-Bootstrap"
    Protected = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_user_group_membership" "terraform_membership" {
  user   = aws_iam_user.terraform_user.name
  groups = [aws_iam_group.admins.name]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_user_policy_attachment" "terraform_admin_policy" {
  user       = aws_iam_user.terraform_user.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

  lifecycle {
    prevent_destroy = true
  }
}

# ============================================================================
# OTROS USUARIOS ADMINISTRADORES (SIN PROTECCIÓN)
# ============================================================================

locals {
  # Filtrar retrogamecloud-terraform de la lista
  other_admin_users = [for user in var.admin_users : user if user != "retrogamecloud-terraform"]
}

resource "aws_iam_user" "users" {
  for_each      = toset(local.other_admin_users)
  name          = each.key
  force_destroy = false

  tags = {
    Role      = "Administrator"
    ManagedBy = "Terraform-Bootstrap"
  }
}

resource "aws_iam_user_group_membership" "admin_membership" {
  for_each = toset(local.other_admin_users)
  user     = aws_iam_user.users[each.key].name
  groups   = [aws_iam_group.admins.name]
}

resource "aws_iam_user_policy_attachment" "user_admin_policy" {
  for_each   = toset(local.other_admin_users)
  user       = aws_iam_user.users[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_access_key" "keys" {
  for_each = toset(local.other_admin_users)
  user     = aws_iam_user.users[each.key].name
}

resource "aws_iam_user_login_profile" "user_passwords" {
  for_each                = toset(local.other_admin_users)
  user                    = aws_iam_user.users[each.key].name
  password_length         = 32
  password_reset_required = true

  lifecycle {
    ignore_changes = [password_reset_required]
  }
}
