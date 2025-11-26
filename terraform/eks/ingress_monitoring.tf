# ============================================================
# INGRESS RESOURCES PARA MONITORING CON OAUTH2
# ============================================================
# Configuración de Ingress para Grafana, Prometheus y AlertManager
# con autenticación OAuth2 via GitHub

# Ingress para Grafana con OAuth2
resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana-ingress"
    namespace = "monitoring"
    annotations = {
      "nginx.ingress.kubernetes.io/auth-url"              = "http://oauth2-proxy.monitoring.svc.cluster.local:4180/oauth2/auth"
      "nginx.ingress.kubernetes.io/auth-signin"           = "https://retrogamehub.games/oauth2/start?rd=$escaped_request_uri"
      "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,Authorization"
      "nginx.ingress.kubernetes.io/proxy-buffer-size"     = "8k"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/grafana/"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-stack-grafana"
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
    helm_release.ingress_nginx,
    kubernetes_deployment.oauth2_proxy
  ]
}

# Ingress para Prometheus con OAuth2
resource "kubernetes_ingress_v1" "prometheus" {
  metadata {
    name      = "prometheus-ingress"
    namespace = "monitoring"
    annotations = {
      "nginx.ingress.kubernetes.io/auth-url"              = "http://oauth2-proxy.monitoring.svc.cluster.local:4180/oauth2/auth"
      "nginx.ingress.kubernetes.io/auth-signin"           = "https://retrogamehub.games/oauth2/start?rd=$escaped_request_uri"
      "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,Authorization"
      "nginx.ingress.kubernetes.io/proxy-buffer-size"     = "8k"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/prometheus/"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-stack-prometheus"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.ingress_nginx,
    kubernetes_deployment.oauth2_proxy
  ]
}

# Ingress para AlertManager con OAuth2
resource "kubernetes_ingress_v1" "alertmanager" {
  metadata {
    name      = "alertmanager-ingress"
    namespace = "monitoring"
    annotations = {
      "nginx.ingress.kubernetes.io/auth-url"              = "http://oauth2-proxy.monitoring.svc.cluster.local:4180/oauth2/auth"
      "nginx.ingress.kubernetes.io/auth-signin"           = "https://retrogamehub.games/oauth2/start?rd=$escaped_request_uri"
      "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,Authorization"
      "nginx.ingress.kubernetes.io/proxy-buffer-size"     = "8k"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/alertmanager/"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-stack-alertmanager"
              port {
                number = 9093
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.ingress_nginx,
    kubernetes_deployment.oauth2_proxy
  ]
}

# Ingress para OAuth2-Proxy callback (sin autenticación)
resource "kubernetes_ingress_v1" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy-ingress"
    namespace = "monitoring"
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/oauth2"
          path_type = "Prefix"

          backend {
            service {
              name = "oauth2-proxy"
              port {
                number = 4180
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.ingress_nginx,
    kubernetes_deployment.oauth2_proxy
  ]
}
