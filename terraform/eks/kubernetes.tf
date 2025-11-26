# Namespace
resource "kubernetes_namespace" "retrogame" {
  metadata {
    name = "retrogame"
  }

  depends_on = [
    module.eks,
    data.aws_eks_cluster.cluster,
    data.aws_eks_cluster_auth.cluster
  ]
}

# JWT Secret
resource "kubernetes_secret" "jwt_secret" {
  metadata {
    name      = "jwt-secret"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  data = {
    JWT_SECRET = var.jwt_secret
  }

  depends_on = [module.eks]
}

# Backend Deployment - COMENTADO: Ahora gestionado por ArgoCD en namespace retrogameargo
# Descomentar si se quiere volver a gestionar con Terraform
/* 
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = "retrogamehub/backend:latest"

          port {
            container_port = 3000
          }

          env {
            name  = "PORT"
            value = "3000"
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_credentials.metadata[0].name
                key  = "DATABASE_URL"
              }
            }
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jwt_secret.metadata[0].name
                key  = "JWT_SECRET"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m" # Optimizado para t3.micro
              memory = "256Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.postgres_credentials,
    kubernetes_secret.jwt_secret
  ]
}
*/

# Backend Service - COMENTADO: Ahora gestionado por ArgoCD
/* 
resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend-service"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.backend]
}
*/

# ConfigMap para reemplazar URLs en frontend (se actualiza después con las URLs reales)
resource "kubernetes_config_map" "frontend_replacer" {
  metadata {
    name      = "frontend-replacer"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  data = {
    "replace-urls.sh" = replace(replace(<<-EOT
      #!/bin/sh
      set -e
      echo "Starting URL replacement..."
      echo "Load Balancer URL: $LOAD_BALANCER_URL"
      echo "CDN URL: $CDN_URL"
      
      cd /app
      echo "Files in /app before replacement:"
      ls -la
      
      find . -name "*.html" -type f | while read file; do
        echo "Processing $file..."
        sed -i "s|http://localhost:8000|$LOAD_BALANCER_URL|g" "$file"
        sed -i "s|http://localhost:8086|$CDN_URL|g" "$file"
        sed -i "s|PLACEHOLDER_LB_URL|$LOAD_BALANCER_URL|g" "$file"
        # Reemplazar rutas relativas a CDN para imágenes y juegos
        sed -i "s#src=\"/img/#src=\"$CDN_URL/img/#g" "$file"
        sed -i "s#const CDN_URL = window.CDN_URL || '/juegos'#const CDN_URL = window.CDN_URL || '$CDN_URL/juegos'#g" "$file"
        echo "Replaced URLs in $file"
      done
      
      echo "URL replacement completed!"
    EOT
    , "\r", ""), "      \n", "\n")
  }

  depends_on = [module.eks]
}

# Frontend Deployment - COMENTADO: Ahora gestionado por ArgoCD
/* 
resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
        annotations = {
          # Forzar recreación del pod cuando cambie el configmap
          "configmap.checksum" = sha256(jsonencode(kubernetes_config_map.frontend_replacer.data))
          # Nota: usamos frontend_replacer inicial, la actualización la maneja kubernetes_config_map_v1_data
        }
      }

      spec {
        # Init container 1: Copiar archivos de la imagen al volumen compartido
        init_container {
          name    = "copy-files"
          image   = "retrogamehub/frontend:latest"
          command = ["sh", "-c", "cp -r /app/* /shared/ && cp -r /app/.[^.]* /shared/ 2>/dev/null || true && ls -la /shared"]

          volume_mount {
            name       = "app-files"
            mount_path = "/shared"
          }
        }

        # Init container 2: Reemplazar URLs en los archivos copiados
        init_container {
          name    = "url-replacer"
          image   = "busybox:1.35"
          command = ["sh", "/scripts/replace-urls.sh"]

          volume_mount {
            name       = "app-files"
            mount_path = "/app"
          }

          volume_mount {
            name       = "replacer-script"
            mount_path = "/scripts"
          }
        }

        container {
          name  = "frontend"
          image = "retrogamehub/frontend:latest"

          port {
            container_port = 8081
          }

          env {
            name  = "PORT"
            value = "8081"
          }

          volume_mount {
            name       = "app-files"
            mount_path = "/app"
            sub_path   = ""
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }
        }

        volume {
          name = "app-files"
          empty_dir {}
        }

        volume {
          name = "replacer-script"
          config_map {
            name         = kubernetes_config_map.frontend_replacer.metadata[0].name
            default_mode = "0755"
          }
        }
      }
    }
  }

  depends_on = [module.eks]
}
*/

# Frontend Service - COMENTADO: Ahora gestionado por ArgoCD
/* 
resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend-service"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 8081
      target_port = 8081
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.frontend]
}
*/

# Kong ConfigMap
resource "kubernetes_config_map" "kong" {
  metadata {
    name      = "kong-declarative-config"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  data = {
    "kong.yml" = <<-EOT
      _format_version: "3.0"

      services:
        - name: backend-service
          url: http://backend-service.retrogame.svc.cluster.local:3000
          routes:
            - name: backend-route
              paths:
                - /api
              strip_path: false

        - name: frontend-service
          url: http://frontend-service.retrogame.svc.cluster.local:8081
          routes:
            - name: frontend-route
              paths:
                - /

      plugins:
        - name: cors
          config:
            origins:
              - "*"
            methods:
              - GET
              - POST
              - PUT
              - DELETE
              - OPTIONS
            headers:
              - Accept
              - Authorization
              - Content-Type
            exposed_headers:
              - X-Auth-Token
            credentials: true
            max_age: 3600
    EOT
  }

  depends_on = [module.eks]
}

# Kong Deployment - COMENTADO: Ahora gestionado por ArgoCD
/* 
resource "kubernetes_deployment" "kong" {
  wait_for_rollout = false # Temporalmente desactivado para permitir escalado de nodos

  metadata {
    name      = "kong"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kong"
      }
    }

    template {
      metadata {
        labels = {
          app = "kong"
        }
      }

      spec {
        container {
          name  = "kong"
          image = "retrogamehub/kong:latest"

          port {
            container_port = 8000
            name           = "proxy"
          }

          env {
            name  = "KONG_DATABASE"
            value = "off"
          }

          env {
            name  = "KONG_DECLARATIVE_CONFIG"
            value = "/etc/kong/kong.yml"
          }

          env {
            name  = "KONG_PROXY_LISTEN"
            value = "0.0.0.0:8000"
          }

          env {
            name  = "KONG_LOG_LEVEL"
            value = "info"
          }

          volume_mount {
            name       = "kong-config"
            mount_path = "/etc/kong"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "50m" # Reducido para t3.micro
              memory = "128Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }
        }

        volume {
          name = "kong-config"
          config_map {
            name = kubernetes_config_map.kong.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map.kong,
    kubernetes_service.backend,
    kubernetes_service.frontend,
    aws_cloudfront_distribution.games_cdn
  ]
}
*/

# Kong Service (LoadBalancer) - COMENTADO: Ahora gestionado por ArgoCD
/* 
resource "kubernetes_service" "kong" {
  metadata {
    name      = "kong-service"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    }
  }

  spec {
    selector = {
      app = "kong"
    }

    port {
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  timeouts {
    create = "2m"
  }

  depends_on = [kubernetes_deployment.kong]
}
*/

# Ingress para Backend (API directamente, sin Kong) - COMENTADO: Los servicios son gestionados por ArgoCD
# Los ingress se configuran en los manifiestos de ArgoCD
/* 
resource "kubernetes_ingress_v1" "backend" {
  metadata {
    name      = "backend-ingress"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/use-regex"    = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/api(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service.backend.metadata[0].name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.backend,
    helm_release.ingress_nginx
  ]
}
*/

# Ingress para Wiki (Mintlify) - proxy externo con soporte para assets
resource "kubernetes_ingress_v1" "wiki" {
  metadata {
    name      = "wiki-ingress"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect"        = "true"
      "nginx.ingress.kubernetes.io/backend-protocol"    = "HTTPS"
      "nginx.ingress.kubernetes.io/upstream-vhost"      = "retrogamecloud.mintlify.app"
      "nginx.ingress.kubernetes.io/use-regex"           = "true"
      "nginx.ingress.kubernetes.io/proxy-ssl-verify"    = "off"
      "nginx.ingress.kubernetes.io/proxy-ssl-protocols" = "TLSv1.2 TLSv1.3"
      "nginx.ingress.kubernetes.io/rewrite-target"      = "/$2"
      "nginx.ingress.kubernetes.io/configuration-snippet" = <<-EOT
        sub_filter_once off;
        sub_filter_types text/html;
        sub_filter '</head>' '<script>
(function() {
  const originalPushState = history.pushState;
  const originalReplaceState = history.replaceState;
  
  function addWikiPrefix(url) {
    if (!url) return url;
    if (url.startsWith("http") || url.startsWith("//")) return url;
    if (url.startsWith("/wiki/")) return url;
    if (url.startsWith("#")) return url;
    if (url.startsWith("/mintlify-assets")) return url;
    if (url.startsWith("/_next")) return url;
    if (url.startsWith("/_mintlify")) return url;
    if (url.startsWith("/api/")) return url;
    if (url.includes("?_rsc=")) return url;
    if (url === "/") return "/wiki/";
    if (url.startsWith("/")) return "/wiki" + url;
    return url;
  }
  
  history.pushState = function(state, title, url) {
    return originalPushState.call(this, state, title, addWikiPrefix(url));
  };
  
  history.replaceState = function(state, title, url) {
    return originalReplaceState.call(this, state, title, addWikiPrefix(url));
  };
  
  document.addEventListener("click", function(e) {
    const link = e.target.closest("a");
    if (!link) return;
    
    const href = link.getAttribute("href");
    if (!href) return;
    if (href.startsWith("http") || href.startsWith("//")) return;
    if (href.startsWith("/wiki/")) return;
    if (href.startsWith("#")) return;
    if (href.startsWith("/mintlify-assets")) return;
    if (href === "/") {
      e.preventDefault();
      window.location.href = "/wiki/";
      return;
    }
    if (href.startsWith("/") && !href.includes("?_rsc=")) {
      e.preventDefault();
      window.location.href = "/wiki" + href;
    }
  }, true);
})();
</script></head>';
        proxy_set_header Accept-Encoding "";
      EOT
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/wiki(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "wiki-external-service"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.ingress_nginx,
    kubernetes_service.wiki_external
  ]
}

# Ingress adicional para assets de Mintlify
resource "kubernetes_ingress_v1" "wiki_assets" {
  metadata {
    name      = "wiki-assets-ingress"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect"        = "true"
      "nginx.ingress.kubernetes.io/backend-protocol"    = "HTTPS"
      "nginx.ingress.kubernetes.io/upstream-vhost"      = "retrogamecloud.mintlify.app"
      "nginx.ingress.kubernetes.io/use-regex"           = "true"
      "nginx.ingress.kubernetes.io/proxy-ssl-verify"    = "off"
      "nginx.ingress.kubernetes.io/proxy-ssl-protocols" = "TLSv1.2 TLSv1.3"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/mintlify-assets"
          path_type = "Prefix"

          backend {
            service {
              name = "wiki-external-service"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.ingress_nginx,
    kubernetes_service.wiki_external
  ]
}

# Service externo para Mintlify
resource "kubernetes_service" "wiki_external" {
  metadata {
    name      = "wiki-external-service"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  spec {
    type          = "ExternalName"
    external_name = "retrogamecloud.mintlify.app"

    port {
      port        = 443
      target_port = 443
      protocol    = "TCP"
    }
  }
}

# Ingress para Frontend (debe ir después de otros paths para que tengan prioridad) - COMENTADO
/* 
resource "kubernetes_ingress_v1" "frontend" {
  metadata {
    name      = "frontend-ingress"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "retrogamehub.games"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.frontend.metadata[0].name
              port {
                number = 8081
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.frontend,
    helm_release.ingress_nginx,
    kubernetes_ingress_v1.backend,
    kubernetes_ingress_v1.wiki
  ]
}
*/

# ConfigMap con el script SQL de inicialización
resource "kubernetes_config_map" "db_init_script" {
  metadata {
    name      = "db-init-script"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  data = {
    "01-schema.sql" = file("${path.module}/../../../backend/init-db/01-schema.sql")
  }

  depends_on = [module.eks]
}

# Job para inicializar la base de datos
resource "kubernetes_job" "db_init" {
  metadata {
    name      = "db-init"
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "db-init"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "db-init"
          image = "postgres:15-alpine"

          command = [
            "sh",
            "-c",
            "psql $DATABASE_URL_PSQL -f /scripts/01-schema.sql"
          ]

          env {
            name = "DATABASE_URL_PSQL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_credentials.metadata[0].name
                key  = "DATABASE_URL_PSQL"
              }
            }
          }

          volume_mount {
            name       = "init-script"
            mount_path = "/scripts"
          }
        }

        volume {
          name = "init-script"
          config_map {
            name = kubernetes_config_map.db_init_script.metadata[0].name
          }
        }
      }
    }

    backoff_limit = 4
  }

  wait_for_completion = false

  depends_on = [
    aws_db_instance.postgres,
    kubernetes_secret.postgres_credentials,
    kubernetes_config_map.db_init_script
  ]
}

# Null resource para verificar las tablas creadas
resource "null_resource" "verify_db_tables" {
  triggers = {
    job_id = kubernetes_job.db_init.metadata[0].uid
  }

  provisioner "local-exec" {
    command = replace(<<-EOT
      echo "⏳ Esperando a que el job de inicialización complete..."
      kubectl wait --for=condition=complete --timeout=120s job/db-init -n retrogame || true
      
      echo "🔍 Verificando tablas creadas en PostgreSQL..."
      echo "Tablas en la base de datos:"
      kubectl run db-verify-tables --rm -i --restart=Never --image=postgres:15-alpine -n retrogame \
        --env="PGPASSWORD=${var.db_password}" \
        -- psql "postgresql://${var.db_username}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require" \
        -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;" 2>&1 | grep -v "pod" | tail -n +3 || true
      
      echo ""
      echo "Total de registros en users:"
      kubectl run db-count-users --rm -i --restart=Never --image=postgres:15-alpine -n retrogame \
        --env="PGPASSWORD=${var.db_password}" \
        -- psql "postgresql://${var.db_username}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require" \
        -c "SELECT COUNT(*) as total_users FROM users;" 2>&1 | grep -v "pod" | tail -n +3 || true
      
      echo "✅ Verificación completada"
    EOT
    , "\r", "")
  }

  depends_on = [
    kubernetes_job.db_init
  ]
}

# ConfigMap actualizado con URLs reales después de crear Kong y CloudFront
resource "kubernetes_config_map_v1_data" "frontend_urls" {
  metadata {
    name      = kubernetes_config_map.frontend_replacer.metadata[0].name
    namespace = kubernetes_namespace.retrogame.metadata[0].name
  }

  data = {
    "replace-urls.sh" = replace(replace(<<-EOT
      #!/bin/sh
      set -e
      LB_URL="https://retrogamehub.games"
      CDN_URL="https://${aws_cloudfront_distribution.games_cdn.domain_name}"
      
      echo "Starting URL replacement..."
      echo "Load Balancer URL: $${LB_URL}"
      echo "CDN URL: $${CDN_URL}"
      
      cd /app
      echo "Files in /app before replacement:"
      ls -la
      
      find . -name "*.html" -type f | while read file; do
        echo "Processing $${file}..."
        sed -i "s|http://localhost:8000|$${LB_URL}|g" "$${file}"
        sed -i "s|http://localhost:8086|$${CDN_URL}|g" "$${file}"
        sed -i "s|PLACEHOLDER_LB_URL|$${LB_URL}|g" "$${file}"
        # Reemplazar rutas relativas a CDN para imágenes y juegos
        sed -i "s#src=\"/img/#src=\"$${CDN_URL}/img/#g" "$${file}"
        sed -i "s#const CDN_URL = window.CDN_URL || '/juegos'#const CDN_URL = window.CDN_URL || '$${CDN_URL}/juegos'#g" "$${file}"
        echo "✓ Replaced URLs in $${file}"
      done
      
      echo "URL replacement completed!"
    EOT
    , "\r", ""), "      \n", "\n")
  }

  force = true

  depends_on = [
    # kubernetes_service.kong,  # Kong not deployed yet
    aws_cloudfront_distribution.games_cdn,
    kubernetes_config_map.frontend_replacer
  ]
}

# Null resource para aplicar el rollout restart del frontend - COMENTADO: Frontend gestionado por ArgoCD
/* 
resource "null_resource" "restart_frontend" {
  triggers = {
    config_version = kubernetes_config_map_v1_data.frontend_urls.data["replace-urls.sh"]
  }

  provisioner "local-exec" {
    command = replace(<<-EOT
      echo "⏳ Esperando propagación de ConfigMap y registro de ALB targets..."
      sleep 30
      
      echo "🔄 Reiniciando deployment frontend..."
      kubectl rollout restart deployment/frontend -n retrogame || echo "⚠️  Restart falló, continuando..."
      
      echo "⏳ Esperando a que el nuevo pod esté Ready..."
      kubectl rollout status deployment/frontend -n retrogame --timeout=120s || echo "⚠️  Timeout esperando rollout"
      
      echo "✅ Proceso completado"
    EOT
    , "\r", "")
  }

  depends_on = [
    kubernetes_deployment.frontend,
    kubernetes_config_map_v1_data.frontend_urls,
    null_resource.register_targets
  ]
}
*/
