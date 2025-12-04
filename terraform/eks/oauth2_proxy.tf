# ============================================================
# OAUTH2-PROXY CON AUTENTICACIÓN DE GITHUB
# ============================================================
# Este archivo configura oauth2-proxy para autenticación OAuth de GitHub
# protegiendo los endpoints de Grafana, Prometheus y AlertManager

# Generar un cookie secret aleatorio para oauth2-proxy
resource "random_password" "oauth2_proxy_cookie_secret" {
  length  = 32
  special = true
}

# Credenciales de GitHub OAuth App (crear en: https://github.com/settings/developers)
# IMPORTANTE: Necesitas crear una GitHub OAuth App y proporcionar:
# 1. Homepage URL: https://retrogamehub.games
# 2. Authorization callback URL: https://retrogamehub.games/oauth2/callback
# 3. Después de la creación, guarda el Client ID y Client Secret

# Kubernetes secret para configuración de oauth2-proxy
resource "kubernetes_secret" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = "monitoring"
  }

  data = {
    # Credenciales de OAuth2 Proxy (Retro Game Hun Oauth)
    client-id     = local.oauth2_proxy_client_id
    client-secret = local.oauth2_proxy_client_secret
    cookie-secret = base64encode(random_password.oauth2_proxy_cookie_secret.result)
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ConfigMap para configuración de oauth2-proxy
resource "kubernetes_config_map" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = "monitoring"
  }

  data = {
    "oauth2_proxy.cfg" = <<-EOT
      # Proveedor OAuth2
      provider = "github"
      
      # Dominios de email - dejar vacío para permitir cualquier usuario de GitHub
      # O configurar al dominio de tu organización, ej: "tuempresa.com"
      email_domains = [ "*" ]
      
      # Restringir a una organización específica de GitHub
      github_org = "retrogamecloud"
      
      # Restringir a un equipo específico de GitHub (opcional)
      # Requiere que github_org esté configurado
      # github_team = "nombre-de-tu-equipo"
      
      # Restringir a usuarios específicos de GitHub (opcional)
      # github_users = [ "usuario1", "usuario2" ]
      
      # Configuración de upstream con path-based routing
      # Usando static:// para indicar que NO hacemos proxy, solo autenticamos
      # El ALB enviará el tráfico directamente a los servicios después de pasar por oauth2-proxy
      upstreams = [ "static://202" ]
      
      # Configuración HTTP
      http_address = "0.0.0.0:4180"
      
      # URL de callback OAuth (CRÍTICO para que GitHub redirija correctamente)
      redirect_url = "https://retrogamehub.games/oauth2/callback"
      
      # Configuración de cookies
      cookie_name = "_oauth2_proxy"
      cookie_secure = true
      cookie_httponly = true
      cookie_samesite = "lax"
      cookie_domains = [ ".retrogamehub.games" ]
      cookie_path = "/"
      
      # Configuración de sesión
      cookie_expire = "168h"  # 7 días
      cookie_refresh = "1h"
      
      # Pasar headers al upstream
      pass_access_token = false
      pass_authorization_header = true
      pass_user_headers = true
      set_xauthrequest = true
      set_authorization_header = true
      
      # Logging
      request_logging = true
      auth_logging = true
      
      # Seguridad
      reverse_proxy = true
      
      # Omitir autenticación para health checks y OAuth callback
      skip_auth_routes = [
        "^/ping$",
        "^/oauth2/callback$"
      ]
    EOT
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# Deployment para oauth2-proxy
resource "kubernetes_deployment" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = "monitoring"
    labels = {
      app = "oauth2-proxy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "oauth2-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "oauth2-proxy"
        }
      }

      spec {
        container {
          name  = "oauth2-proxy"
          image = "quay.io/oauth2-proxy/oauth2-proxy:v7.6.0"
          
          args = [
            "--config=/etc/oauth2-proxy/oauth2_proxy.cfg",
            "--client-id=$(CLIENT_ID)",
            "--client-secret=$(CLIENT_SECRET)",
            "--cookie-secret=$(COOKIE_SECRET)",
            "--redirect-url=https://retrogamehub.games/oauth2/callback"
          ]

          env {
            name = "CLIENT_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.oauth2_proxy.metadata[0].name
                key  = "client-id"
              }
            }
          }

          env {
            name = "CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.oauth2_proxy.metadata[0].name
                key  = "client-secret"
              }
            }
          }

          env {
            name = "COOKIE_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.oauth2_proxy.metadata[0].name
                key  = "cookie-secret"
              }
            }
          }

          port {
            container_port = 4180
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path   = "/ping"
              port   = 4180
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path   = "/ping"
              port   = 4180
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/oauth2-proxy"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.oauth2_proxy.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.oauth2_proxy]
}

# Service para oauth2-proxy
resource "kubernetes_service" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = "monitoring"
    labels = {
      app = "oauth2-proxy"
    }
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
    }
  }

  spec {
    type = "ClusterIP"
    
    selector = {
      app = "oauth2-proxy"
    }

    port {
      name        = "http"
      port        = 4180
      target_port = 4180
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.oauth2_proxy]
}

# Output del nombre del servicio oauth2-proxy para configuración de ALB
output "oauth2_proxy_service_name" {
  description = "Nombre del servicio oauth2-proxy"
  value       = kubernetes_service.oauth2_proxy.metadata[0].name
}
