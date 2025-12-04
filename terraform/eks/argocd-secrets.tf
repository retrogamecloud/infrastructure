# ============================================================================
# Secretos de ArgoCD gestionados por Terraform
# ============================================================================
#
# IMPORTANTE: Los valores sensibles se leen desde AWS Secrets Manager
# Los data sources están definidos en secrets-data.tf
#
# ============================================================================

# ArgoCD main secret (ArgoCD Helm chart lo crea automáticamente)
# Usamos kubectl patch para agregar los valores de OAuth sin conflictos
resource "null_resource" "argocd_secret_oauth" {
  triggers = {
    client_id     = local.argocd_oauth_client_id
    client_secret = local.argocd_oauth_client_secret
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl patch secret argocd-secret -n argocd \
        --type merge \
        -p '{"data":{"dex.github.clientID":"${base64encode(local.argocd_oauth_client_id)}","dex.github.clientSecret":"${base64encode(local.argocd_oauth_client_secret)}"}}'
    EOT
  }

  depends_on = [helm_release.argocd]
}

# Generate random secret key for ArgoCD server encryption
resource "random_password" "argocd_server_secret" {
  length  = 32
  special = false
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

# NOTA: ArgoCD crea automáticamente el secret "argocd-notifications-secret".
# Para configurar Slack posteriormente:
# kubectl -n argocd edit secret argocd-notifications-secret
# Agregar: slack-token: <tu-token>
