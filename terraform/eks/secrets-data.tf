# ============================================================================
# AWS Secrets Manager - Local Values from Resources
# ============================================================================
#
# Este archivo define locals que referencian directamente los secretos
# CREADOS en secrets-manager.tf (usando recursos, no data sources)
#
# Esto permite que Terraform gestione los secretos sin dependencias circulares
# Los secretos OAuth se leen mediante data sources porque existen previamente
#
# ============================================================================

# ============================================================================
# GitHub OAuth Apps - Data sources para secretos que ya existen en AWS
# ============================================================================

# Grafana OAuth (creado manualmente en AWS)
data "aws_secretsmanager_secret" "grafana_oauth" {
  name = "prod/retrogame/grafana-oauth"
}

data "aws_secretsmanager_secret_version" "grafana_oauth" {
  secret_id = data.aws_secretsmanager_secret.grafana_oauth.id
}

# ArgoCD OAuth (creado manualmente en AWS)
data "aws_secretsmanager_secret" "argocd_oauth" {
  name = "prod/retrogame/argocd-oauth"
}

data "aws_secretsmanager_secret_version" "argocd_oauth" {
  secret_id = data.aws_secretsmanager_secret.argocd_oauth.id
}

# OAuth2 Proxy (creado manualmente en AWS)
data "aws_secretsmanager_secret" "oauth2_proxy" {
  name = "prod/retrogame/oauth2-proxy"
}

data "aws_secretsmanager_secret_version" "oauth2_proxy" {
  secret_id = data.aws_secretsmanager_secret.oauth2_proxy.id
}

# ============================================================================
# Locals para uso en toda la configuración
# ============================================================================

locals {
  # Secretos gestionados por Terraform (desde secrets-manager.tf)
  github_token      = aws_secretsmanager_secret_version.github_token.secret_string
  db_username       = aws_secretsmanager_secret_version.db_username.secret_string
  db_password       = aws_secretsmanager_secret_version.db_password.secret_string
  jwt_secret        = aws_secretsmanager_secret_version.jwt_secret.secret_string
  slack_bot_token   = aws_secretsmanager_secret_version.slack_bot_token.secret_string
  slack_webhook_url = aws_secretsmanager_secret_version.slack_webhook_url.secret_string

  # Parse GitHub OAuth JSONs (desde data sources)
  grafana_oauth      = jsondecode(data.aws_secretsmanager_secret_version.grafana_oauth.secret_string)
  argocd_oauth       = jsondecode(data.aws_secretsmanager_secret_version.argocd_oauth.secret_string)
  oauth2_proxy_oauth = jsondecode(data.aws_secretsmanager_secret_version.oauth2_proxy.secret_string)

  # OAuth credentials para cada servicio
  grafana_oauth_client_id     = local.grafana_oauth.client_id
  grafana_oauth_client_secret = local.grafana_oauth.client_secret
  argocd_oauth_client_id      = local.argocd_oauth.client_id
  argocd_oauth_client_secret  = local.argocd_oauth.client_secret
  oauth2_proxy_client_id      = local.oauth2_proxy_oauth.client_id
  oauth2_proxy_client_secret  = local.oauth2_proxy_oauth.client_secret
}
