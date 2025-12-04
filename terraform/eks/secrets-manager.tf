# ============================================================================
# AWS Secrets Manager - Secrets Creation
# ============================================================================
#
# Este archivo crea todos los secretos en AWS Secrets Manager
# Una vez creados, se pueden eliminar o comentar para evitar sobrescribir
#
# IMPORTANTE: Después de crear los secretos, eliminar este archivo o
# comentar los recursos para que Terraform solo LEA los secretos
#
# ============================================================================

# GitHub Token para ArgoCD
resource "aws_secretsmanager_secret" "github_token" {
  name        = "prod/retrogame/github-token"
  description = "GitHub Personal Access Token para ArgoCD"
  
  recovery_window_in_days = 0

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "retrogame"
  }
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token
}

# Database Password
resource "aws_secretsmanager_secret" "db_password" {
  name        = "prod/retrogame/db-password"
  description = "PostgreSQL database password"
  
  recovery_window_in_days = 0

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "retrogame"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "prod/retrogame/jwt-secret"
  description = "JWT secret for authentication service"
  
  recovery_window_in_days = 0

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "retrogame"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}

# ============================================================================
# GitHub OAuth Apps - Secretos separados para cada servicio
# ============================================================================

# ============================================================================
# NOTA: Los secretos OAuth ya fueron creados manualmente en AWS Secrets Manager
# Solo se gestionan mediante data sources en secrets-data.tf para leer sus valores
# Para actualizarlos, usar AWS CLI o la consola de AWS
# ============================================================================

# Grafana OAuth - Ya existe en AWS, se lee via data source
# ArgoCD OAuth - Ya existe en AWS, se lee via data source  
# OAuth2 Proxy - Ya existe en AWS, se lee via data source

# Slack Bot Token
resource "aws_secretsmanager_secret" "slack_bot_token" {
  name        = "prod/retrogame/slack-bot-token"
  description = "Slack Bot Token para notificaciones de ArgoCD"
  
  recovery_window_in_days = 0

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "retrogame"
  }
}

resource "aws_secretsmanager_secret_version" "slack_bot_token" {
  secret_id     = aws_secretsmanager_secret.slack_bot_token.id
  secret_string = var.slack_bot_token
}

# Slack Webhook URL
resource "aws_secretsmanager_secret" "slack_webhook_url" {
  name        = "prod/retrogame/slack-webhook-url"
  description = "Slack Incoming Webhook URL para alertas de Prometheus"
  
  recovery_window_in_days = 0

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "retrogame"
  }
}

resource "aws_secretsmanager_secret_version" "slack_webhook_url" {
  secret_id     = aws_secretsmanager_secret.slack_webhook_url.id
  secret_string = var.slack_webhook_url
}

# Database Username (menos sensible pero por consistencia)
resource "aws_secretsmanager_secret" "db_username" {
  name        = "prod/retrogame/db-username"
  description = "PostgreSQL database username"
  
  recovery_window_in_days = 0

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "retrogame"
  }
}

resource "aws_secretsmanager_secret_version" "db_username" {
  secret_id     = aws_secretsmanager_secret.db_username.id
  secret_string = var.db_username
}
