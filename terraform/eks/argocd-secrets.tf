# ============================================================================
# Secretos de ArgoCD gestionados por Terraform
# ============================================================================
#
# IMPORTANTE: Los valores sensibles se leen desde AWS Secrets Manager
# Los data sources están definidos en secrets-data.tf
#
# ============================================================================

# NOTA: ArgoCD crea automáticamente el secret "argocd-secret" al instalarse.
# Si necesitas configurar OAuth u otras opciones, hazlo mediante argocd-cm ConfigMap
# o a través de la UI de ArgoCD.
#
# Para configurar GitHub OAuth posteriormente:
# kubectl -n argocd edit cm argocd-cm
# kubectl -n argocd edit secret argocd-secret

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
