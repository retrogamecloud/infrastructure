# ============================================================================
# Monitoring Stack - Prometheus + Grafana + AlertManager
# ============================================================================
#
# Este archivo implementa observabilidad completa en el cluster EKS:
# - Prometheus Operator: Gestiona Prometheus, AlertManager, ServiceMonitors
# - Prometheus Server: Recolecta métricas de Kubernetes y aplicaciones
# - Grafana: Dashboards y visualización de métricas
# - AlertManager: Gestión de alertas y notificaciones
# - Node Exporter: Métricas de nodos EC2
# - Kube State Metrics: Métricas del estado de Kubernetes
#
# IMPORTANTE: Este archivo NO modifica recursos existentes.
# Todos los componentes se despliegan en el namespace "monitoring" separado.
#
# ============================================================================

# Namespace dedicado para componentes de monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
      component = "observability"
    }
  }
}

# ============================================================================
# Prometheus Stack via Helm Chart
# ============================================================================
# 
# Componentes incluidos:
# - Prometheus Operator
# - Prometheus Server (con 3 días de retención)
# - Grafana (con dashboards pre-configurados)
# - AlertManager (alertas básicas)
# - Node Exporter (DaemonSet en todos los nodos)
# - Kube State Metrics
#
# Docs: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
# ============================================================================

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "55.5.0"

  # Valores personalizados para optimizar recursos en t3.micro nodes
  values = [
    yamlencode({
      # ============================================================================
      # Prometheus Server Configuration
      # ============================================================================
      prometheus = {
        prometheusSpec = {
          # Retención de métricas (reducida para ahorrar espacio)
          retention = "3d"
          
          # Recursos ajustados para t3.micro nodes
          resources = {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          # Almacenamiento persistente
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }

          # ServiceMonitor para scraping
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }

        # Service para acceder a Prometheus
        service = {
          type = "ClusterIP"
          port = 9090
        }
      }

      # ============================================================================
      # Grafana Configuration
      # ============================================================================
      grafana = {
        enabled = true

        # Admin credentials (cambiar en producción)
        adminPassword = "admin123"

        # Recursos ajustados
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }

        # Service para acceder a Grafana
        service = {
          type = "ClusterIP"
          port = 80
        }

        # Dashboards pre-configurados
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }

        # Datasources
        datasources = {
          "datasources.yaml" = {
            apiVersion = 1
            datasources = [
              {
                name      = "Prometheus"
                type      = "prometheus"
                url       = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
                access    = "proxy"
                isDefault = true
              }
            ]
          }
        }

        # Persistencia deshabilitada para dev (habilitar en prod)
        persistence = {
          enabled = false
        }
      }

      # ============================================================================
      # AlertManager Configuration
      # ============================================================================
      alertmanager = {
        enabled = true

        alertmanagerSpec = {
          # Recursos ajustados
          resources = {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          # Almacenamiento (pequeño para dev)
          storage = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "2Gi"
                  }
                }
              }
            }
          }
        }

        # Service
        service = {
          type = "ClusterIP"
          port = 9093
        }

        # Configuración básica de alertas (se puede expandir)
        config = {
          global = {
            resolve_timeout = "5m"
          }
          route = {
            group_by        = ["alertname", "cluster", "service"]
            group_wait      = "10s"
            group_interval  = "10s"
            repeat_interval = "12h"
            receiver        = "default"
          }
          receivers = [
            {
              name = "default"
              # TODO: Configurar Slack, email, etc.
            }
          ]
        }
      }

      # ============================================================================
      # Node Exporter - Métricas de Nodos EC2
      # ============================================================================
      nodeExporter = {
        enabled = true
        
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      # ============================================================================
      # Kube State Metrics
      # ============================================================================
      kubeStateMetrics = {
        enabled = true

        resources = {
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

      # ============================================================================
      # Prometheus Operator
      # ============================================================================
      prometheusOperator = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # ============================================================================
      # Default Rules - Alertas básicas
      # ============================================================================
      defaultRules = {
        create = true
        rules = {
          alertmanager            = true
          etcd                    = false  # No aplica para EKS managed
          configReloaders         = true
          general                 = true
          k8s                     = true
          kubeApiserverAvailability = true
          kubeApiserverSlos       = false  # Reducir ruido
          kubelet                 = true
          kubeProxy               = false  # No aplica
          kubePrometheusGeneral   = true
          kubePrometheusNodeRecording = true
          kubernetesApps          = true
          kubernetesResources     = true
          kubernetesStorage       = true
          kubernetesSystem        = true
          kubeScheduler           = false  # No accesible en EKS managed
          kubeStateMetrics        = true
          network                 = true
          node                    = true
          nodeExporterAlerting    = true
          nodeExporterRecording   = true
          prometheus              = true
          prometheusOperator      = true
        }
      }
    })
  ]

  # Esperar a que el cluster EKS esté completamente listo
  depends_on = [
    module.eks,
    kubernetes_namespace.monitoring
  ]

  # No fallar si el chart ya existe (idempotente)
  create_namespace = false
  wait             = true
  timeout          = 600  # 10 minutos para instalación completa
}

# ============================================================================
# Outputs útiles
# ============================================================================

output "prometheus_url" {
  description = "URL interna de Prometheus Server"
  value       = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
}

output "grafana_url" {
  description = "URL interna de Grafana"
  value       = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80"
}

output "alertmanager_url" {
  description = "URL interna de AlertManager"
  value       = "http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093"
}

output "grafana_admin_password" {
  description = "Password del admin de Grafana (cambiar en producción)"
  value       = "admin123"
  sensitive   = true
}

output "grafana_port_forward_command" {
  description = "Comando para acceder a Grafana localmente"
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
}

output "prometheus_port_forward_command" {
  description = "Comando para acceder a Prometheus localmente"
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
}
