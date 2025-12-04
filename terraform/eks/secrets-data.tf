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

# ============================================================================
# GitHub OAuth Apps - Data sources separados
# ============================================================================

# Grafana OAuth
data "aws_secretsmanager_secret" "grafana_oauth" {
  name = "prod/retrogame/grafana-oauth"
}

data "aws_secretsmanager_secret_version" "grafana_oauth" {
  secret_id = data.aws_secretsmanager_secret.grafana_oauth.id
}

# ArgoCD OAuth
data "aws_secretsmanager_secret" "argocd_oauth" {
  name = "prod/retrogame/argocd-oauth"
}

data "aws_secretsmanager_secret_version" "argocd_oauth" {
  secret_id = data.aws_secretsmanager_secret.argocd_oauth.id
}

# OAuth2 Proxy
data "aws_secretsmanager_secret" "oauth2_proxy" {
  name = "prod/retrogame/oauth2-proxy"
}

data "aws_secretsmanager_secret_version" "oauth2_proxy" {
  secret_id = data.aws_secretsmanager_secret.oauth2_proxy.id
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
  # Parse GitHub OAuth JSONs
  grafana_oauth  = jsondecode(data.aws_secretsmanager_secret_version.grafana_oauth.secret_string)
  argocd_oauth   = jsondecode(data.aws_secretsmanager_secret_version.argocd_oauth.secret_string)
  oauth2_proxy_oauth = jsondecode(data.aws_secretsmanager_secret_version.oauth2_proxy.secret_string)
  
  # Extraer valores individuales
  github_token               = data.aws_secretsmanager_secret_version.github_token.secret_string
  db_username                = data.aws_secretsmanager_secret_version.db_username.secret_string
  db_password                = data.aws_secretsmanager_secret_version.db_password.secret_string
  jwt_secret                 = data.aws_secretsmanager_secret_version.jwt_secret.secret_string
  slack_bot_token            = data.aws_secretsmanager_secret_version.slack_bot_token.secret_string
  slack_webhook_url          = data.aws_secretsmanager_secret_version.slack_webhook_url.secret_string
  
  # OAuth credentials para cada servicio
  grafana_oauth_client_id        = local.grafana_oauth.client_id
  grafana_oauth_client_secret    = local.grafana_oauth.client_secret
  argocd_oauth_client_id         = local.argocd_oauth.client_id
  argocd_oauth_client_secret     = local.argocd_oauth.client_secret
  oauth2_proxy_client_id         = local.oauth2_proxy_oauth.client_id
  oauth2_proxy_client_secret     = local.oauth2_proxy_oauth.client_secret
}
