# ============================================================
# INGRESS NGINX CONTROLLER
# ============================================================
# Ingress NGINX para manejar el routing interno y OAuth2-Proxy

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "ClusterIP"  # ClusterIP porque el ALB ya maneja el external access
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
          }
        }
        
        config = {
          # Configuración para trabajar detrás de ALB
          "use-forwarded-headers" = "true"
          "compute-full-forwarded-for" = "true"
          "use-proxy-protocol" = "false"
          
          # Configuración de proxy
          "proxy-body-size" = "50m"
          "proxy-buffer-size" = "8k"
          
          # SSL y HTTPS
          "ssl-redirect" = "false"  # ALB ya maneja SSL
          "force-ssl-redirect" = "false"
          
          # Habilitar snippets para redirects de trailing slash
          "allow-snippet-annotations" = "true"
        }
        
        # Recursos
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        
        # Métricas
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        # Replicas
        replicaCount = 2
        
        # Affinity para distribuir pods
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app.kubernetes.io/name"
                        operator = "In"
                        values   = ["ingress-nginx"]
                      }
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    helm_release.kube_prometheus_stack
  ]
}

# Service para exponer Ingress NGINX al ALB
resource "kubernetes_service" "ingress_nginx_alb" {
  metadata {
    name      = "ingress-nginx-alb"
    namespace = "ingress-nginx"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
    }
  }

  spec {
    type = "ClusterIP"
    
    selector = {
      "app.kubernetes.io/name"      = "ingress-nginx"
      "app.kubernetes.io/instance"  = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }

  depends_on = [helm_release.ingress_nginx]
}

# Output del servicio de Ingress NGINX
output "ingress_nginx_service" {
  description = "Nombre del servicio Ingress NGINX"
  value       = kubernetes_service.ingress_nginx_alb.metadata[0].name
}
