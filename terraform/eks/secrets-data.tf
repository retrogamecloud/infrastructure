# ============================================================================
# AWS Secrets Manager - Data Sources
# ============================================================================
#
# Lee secretos desde AWS Secrets Manager
# Esto permite hacer el repositorio público sin exponer credenciales
#
# Los secretos deben existir previamente en AWS Secrets Manager
# (creados con secrets-manager.tf o manualmente)
#
# ============================================================================

# GitHub Token para ArgoCD repos
data "aws_secretsmanager_secret" "github_token" {
  name = "prod/retrogame/github-token"
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

# Database Password
data "aws_secretsmanager_secret" "db_password" {
  name = "prod/retrogame/db-password"
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

# Database Username
data "aws_secretsmanager_secret" "db_username" {
  name = "prod/retrogame/db-username"
}

data "aws_secretsmanager_secret_version" "db_username" {
  secret_id = data.aws_secretsmanager_secret.db_username.id
}

# JWT Secret
data "aws_secretsmanager_secret" "jwt_secret" {
  name = "prod/retrogame/jwt-secret"
}

data "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = data.aws_secretsmanager_secret.jwt_secret.id
}

# GitHub OAuth
data "aws_secretsmanager_secret" "github_oauth" {
  name = "prod/retrogame/github-oauth"
}

data "aws_secretsmanager_secret_version" "github_oauth" {
  secret_id = data.aws_secretsmanager_secret.github_oauth.id
}

# Slack Bot Token
data "aws_secretsmanager_secret" "slack_bot_token" {
  name = "prod/retrogame/slack-bot-token"
}

data "aws_secretsmanager_secret_version" "slack_bot_token" {
  secret_id = data.aws_secretsmanager_secret.slack_bot_token.id
}

# Slack Webhook URL
data "aws_secretsmanager_secret" "slack_webhook_url" {
  name = "prod/retrogame/slack-webhook-url"
}

data "aws_secretsmanager_secret_version" "slack_webhook_url" {
  secret_id = data.aws_secretsmanager_secret.slack_webhook_url.id
}

# ============================================================================
# Locals para parsear secretos
# ============================================================================

locals {
  # Parse GitHub OAuth JSON
  github_oauth = jsondecode(data.aws_secretsmanager_secret_version.github_oauth.secret_string)
  
  # Extraer valores individuales
  github_token               = data.aws_secretsmanager_secret_version.github_token.secret_string
  db_username                = data.aws_secretsmanager_secret_version.db_username.secret_string
  db_password                = data.aws_secretsmanager_secret_version.db_password.secret_string
  jwt_secret                 = data.aws_secretsmanager_secret_version.jwt_secret.secret_string
  github_oauth_client_id     = local.github_oauth.client_id
  github_oauth_client_secret = local.github_oauth.client_secret
  slack_bot_token            = data.aws_secretsmanager_secret_version.slack_bot_token.secret_string
  slack_webhook_url          = data.aws_secretsmanager_secret_version.slack_webhook_url.secret_string
}
