# =============================================================================
# DYNAMODB - TERRAFORM STATE LOCKING
# =============================================================================
# Tabla DynamoDB para gestionar locks y prevenir ejecuciones concurrentes

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Description = "Previene ejecuciones concurrentes de Terraform"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Política IAM para acceso a la tabla DynamoDB
resource "aws_iam_policy" "dynamodb_terraform_lock" {
  name        = "TerraformDynamoDBLockAccess"
  description = "Permite a los usuarios de Terraform usar la tabla de locks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = aws_dynamodb_table.terraform_lock.arn
      }
    ]
  })
}

# Adjuntar política a cada usuario
resource "aws_iam_user_policy_attachment" "dynamodb_lock_access" {
  for_each = toset(var.admin_users)

  user       = each.key
  policy_arn = aws_iam_policy.dynamodb_terraform_lock.arn

  # Asegurar que los usuarios existan antes de adjuntar políticas
  depends_on = [aws_iam_user.users]
}
