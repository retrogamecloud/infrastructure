# ArgoCD Installation
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.6"

  values = [
    templatefile("${path.module}/values/argocd-values.yaml", {
      argocd_oauth_client_id     = local.argocd_oauth_client_id
      argocd_oauth_client_secret = local.argocd_oauth_client_secret
    })
  ]

  depends_on = [
    module.eks
  ]
}

# ArgoCD Ingress (behind OAuth2 Proxy)
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
    annotations = {
      "kubernetes.io/ingress.class"                       = "nginx"
      "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTP"
      "nginx.ingress.kubernetes.io/ssl-redirect"          = "true"
      "nginx.ingress.kubernetes.io/auth-url"              = "https://$host/oauth2/auth"
      "nginx.ingress.kubernetes.io/auth-signin"           = "https://$host/oauth2/start?rd=$escaped_request_uri"
      "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email"
    }
  }

  spec {
    tls {
      hosts       = ["retrogamehub.games"]
      secret_name = "retrogamehub-tls"
    }

    rule {
      host = "retrogamehub.games"
      http {
        path {
          path      = "/argocd"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_deployment.oauth2_proxy
  ]
}

# Output ArgoCD admin password command
output "argocd_admin_password_command" {
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  description = "Command to get ArgoCD admin password"
}
