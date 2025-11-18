# =============================================================================
# S3 BUCKET - TERRAFORM STATE BACKEND
# =============================================================================
# Bucket S3 para almacenar el estado de Terraform de forma remota

resource "aws_s3_bucket" "terraform_state" {
  bucket = "retrogamecloud-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Description = "Almacena el estado de Terraform para todos los proyectos"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Habilitar versionado para recuperación de estados anteriores
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptación del bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acceso público
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Política del bucket para dar acceso a usuarios IAM específicos
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTerraformStateAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            for user in var.admin_users :
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"
          ]
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      }
    ]
  })

  # Asegurar que los usuarios existan antes de crear la política
  depends_on = [aws_iam_user.users]
}
