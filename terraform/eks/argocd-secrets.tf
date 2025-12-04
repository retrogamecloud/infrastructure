# ============================================================================
# Secretos de ArgoCD gestionados por Terraform
# ============================================================================
#
# IMPORTANTE: Los valores sensibles se leen desde AWS Secrets Manager
# Los data sources están definidos en secrets-data.tf
#
# ============================================================================

# Genera una clave secreta aleatoria para el servidor de ArgoCD
resource "random_password" "argocd_server_secret" {
  length  = 32
  special = true
}

# Secret principal de ArgoCD con OAuth y server key
resource "kubernetes_secret" "argocd_secret" {
  metadata {
    name      = "argocd-secret"
    namespace = "argocd"
  }

  type = "Opaque"

  data = {
    "dex.github.clientSecret" = local.github_oauth_client_secret
    "server.secretkey"         = random_password.argocd_server_secret.result
  }

  depends_on = [helm_release.argocd]
}

# Secret para acceso al repositorio de Kubernetes
resource "kubernetes_secret" "argocd_repo_kubernetes" {
  metadata {
    name      = "repo-retrogame-kubernetes"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = "https://github.com/retrogamecloud/kubernetes"
    username = "git"
    password = local.github_token
  }

  depends_on = [helm_release.argocd]
}

# Secret para acceso al repositorio de Infrastructure
resource "kubernetes_secret" "argocd_repo_infrastructure" {
  metadata {
    name      = "repo-retrogame-infrastructure"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = "https://github.com/retrogamecloud/infrastructure.git"
    username = "git"
    password = local.github_token
  }

  depends_on = [helm_release.argocd]
}

# Secret para notificaciones de Slack de ArgoCD
resource "kubernetes_secret" "argocd_notifications_secret" {
  metadata {
    name      = "argocd-notifications-secret"
    namespace = "argocd"
  }

  type = "Opaque"

  data = {
    "slack-token" = local.slack_bot_token
  }

  depends_on = [helm_release.argocd]
}
