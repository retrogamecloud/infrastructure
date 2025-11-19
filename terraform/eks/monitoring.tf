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

# Secret para el webhook de Slack de AlertManager
resource "kubernetes_secret" "alertmanager_slack" {
  metadata {
    name      = "alertmanager-slack-webhook"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    webhook_url = var.slack_webhook_url
  }

  type = "Opaque"
}

# Data source para leer el secret
data "kubernetes_secret" "alertmanager_slack" {
  metadata {
    name      = kubernetes_secret.alertmanager_slack.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  depends_on = [kubernetes_secret.alertmanager_slack]
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
          # Configuración para funcionar bajo subpath /prometheus vía ALB
          externalUrl = "https://retrogamehub.games/prometheus"
          routePrefix = "/prometheus"
          
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
                storageClassName = "gp2"
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

        # Service para acceder a Prometheus (sin ALB)
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

        # Configuración para trabajar con ALB y path /grafana
        "grafana.ini" = {
          server = {
            root_url = "https://retrogamehub.games/grafana"
            serve_from_sub_path = true
          }
          security = {
            allow_embedding = true
            cookie_secure   = false
            cookie_samesite = "lax"
          }
        }

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

        # Service para acceso desde ALB
        service = {
          type = "ClusterIP"
          port = 80
          annotations = {
            "alb.ingress.kubernetes.io/healthcheck-path" = "/grafana/api/health"
          }
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

        # Dashboards personalizados para Retrogame
        dashboards = {
          default = {
            # Dashboard personalizado de la aplicación Retrogame
            retrogame-app = {
              json = file("${path.module}/values/retrogame-dashboard.json")
            }
            
            # Dashboard de Kubernetes Cluster Overview
            kubernetes-cluster = {
              gnetId     = 7249
              revision   = 1
              datasource = "Prometheus"
            }
            
            # Dashboard de Node Exporter
            node-exporter = {
              gnetId     = 1860
              revision   = 31
              datasource = "Prometheus"
            }
            
            # Dashboard de Pods
            kubernetes-pods = {
              gnetId     = 6417
              revision   = 1
              datasource = "Prometheus"
            }

            # Dashboard de recursos del cluster
            kubernetes-resources = {
              gnetId     = 10000
              revision   = 1
              datasource = "Prometheus"
            }

            # Dashboard de Nginx/Kong API Gateway
            kong-dashboard = {
              gnetId     = 7424
              revision   = 5
              datasource = "Prometheus"
            }

            # Dashboard de PostgreSQL (RDS)
            postgresql = {
              gnetId     = 9628
              revision   = 7
              datasource = "Prometheus"
            }
          }
        }

        # Datasources adicionales (opcional)
        additionalDataSources = [
          {
            name   = "Loki"
            type   = "loki"
            url    = "http://loki:3100"
            access = "proxy"
            isDefault = false
            jsonData = {
              maxLines = 1000
            }
          }
        ]

        # El helm chart ya configura automáticamente el datasource de Prometheus
        # No necesitamos configurarlo manualmente para evitar duplicados

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
          # Configuración para funcionar bajo subpath /alertmanager vía ALB
          externalUrl = "https://retrogamehub.games/alertmanager"
          routePrefix = "/alertmanager"
          
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
                storageClassName = "gp2"
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

        # Service para AlertManager accesible desde ALB
        service = {
          type = "ClusterIP"
          port = 9093
          annotations = {
            "alb.ingress.kubernetes.io/healthcheck-path" = "/alertmanager/-/healthy"
          }
        }

        # Configuración de AlertManager con integración Slack
        config = {
          global = {
            resolve_timeout = "5m"
            slack_api_url = data.kubernetes_secret.alertmanager_slack.data["webhook_url"]
          }
          
          # Plantillas de mensajes
          templates = [
            "/etc/alertmanager/config/*.tmpl"
          ]

          # Rutas de enrutamiento de alertas
          route = {
            receiver = "default"
            group_by = ["alertname", "cluster", "namespace", "pod"]
            group_wait = "10s"
            group_interval = "5m"
            repeat_interval = "4h"
            
            # Rutas específicas por severidad
            routes = [
              {
                receiver = "critical-alerts"
                match = {
                  severity = "critical"
                }
                group_wait = "10s"
                repeat_interval = "1h"
              },
              {
                receiver = "warning-alerts"
                match = {
                  severity = "warning"
                }
                group_wait = "30s"
                repeat_interval = "4h"
              },
              {
                receiver = "app-alerts"
                match_re = {
                  namespace = "retrogame"
                }
                group_wait = "10s"
                repeat_interval = "2h"
              }
            ]
          }

          # Inhibiciones - evitar ruido de alertas
          inhibit_rules = [
            {
              source_match = {
                severity = "critical"
              }
              target_match = {
                severity = "warning"
              }
              equal = ["alertname", "namespace", "pod"]
            }
          ]

          # Receptores de notificaciones
          receivers = [
            {
              name = "default"
              slack_configs = [
                {
                  channel = "#notificacionesrgh"
                  title = "🔔 [{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}"
                  text = "{{ range .Alerts }}*Alert:* {{ .Annotations.summary }}\n*Description:* {{ .Annotations.description }}\n*Severity:* {{ .Labels.severity }}\n*Namespace:* {{ .Labels.namespace }}\n{{ end }}"
                  send_resolved = true
                  color = "{{ if eq .Status \"firing\" }}danger{{ else }}good{{ end }}"
                }
              ]
            },
            {
              name = "critical-alerts"
              slack_configs = [
                {
                  channel = "#notificacionesrgh"
                  title = "🚨 [CRITICAL] {{ .GroupLabels.alertname }}"
                  text = "{{ range .Alerts }}*Alert:* {{ .Annotations.summary }}\n*Description:* {{ .Annotations.description }}\n*Namespace:* {{ .Labels.namespace }}\n*Pod:* {{ .Labels.pod }}\n{{ end }}"
                  send_resolved = true
                  color = "danger"
                }
              ]
            },
            {
              name = "warning-alerts"
              slack_configs = [
                {
                  channel = "#notificacionesrgh"
                  title = "⚠️ [WARNING] {{ .GroupLabels.alertname }}"
                  text = "{{ range .Alerts }}*Alert:* {{ .Annotations.summary }}\n*Description:* {{ .Annotations.description }}\n{{ end }}"
                  send_resolved = true
                  color = "warning"
                }
              ]
            },
            {
              name = "app-alerts"
              slack_configs = [
                {
                  channel = "#notificacionesrgh"
                  title = "🎮 [RETROGAME] {{ .GroupLabels.alertname }}"
                  text = "{{ range .Alerts }}*Service:* {{ .Labels.service }}\n*Alert:* {{ .Annotations.summary }}\n*Description:* {{ .Annotations.description }}\n{{ end }}"
                  send_resolved = true
                  color = "{{ if eq .Status \"firing\" }}#FF6B6B{{ else }}#51CF66{{ end }}"
                }
              ]
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

      # ============================================================================
      # Alertas Personalizadas para Retrogame
      # ============================================================================
      additionalPrometheusRulesMap = {
        retrogame-alerts = {
          groups = [
            {
              name = "retrogame-application-alerts"
              interval = "30s"
              rules = [
                {
                  alert = "RetrogamePodDown"
                  expr = "kube_pod_status_phase{namespace=\"retrogame\", phase!=\"Running\"} == 1"
                  for = "2m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "Retrogame pod {{ $labels.pod }} is down"
                    description = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} has been down for more than 2 minutes."
                  }
                },
                {
                  alert = "BackendPodNotRunning"
                  expr = "sum(kube_pod_status_phase{namespace=\"retrogame\", pod=~\"backend.*\", phase=\"Running\"}) == 0"
                  for = "1m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                    service = "backend"
                  }
                  annotations = {
                    summary = "Backend pods not running"
                    description = "No backend pods are running in namespace retrogame."
                  }
                },
                {
                  alert = "FrontendPodNotRunning"
                  expr = "sum(kube_pod_status_phase{namespace=\"retrogame\", pod=~\"frontend.*\", phase=\"Running\"}) == 0"
                  for = "1m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                    service = "frontend"
                  }
                  annotations = {
                    summary = "Frontend pods not running"
                    description = "No frontend pods are running in namespace retrogame."
                  }
                },
                {
                  alert = "KongPodNotRunning"
                  expr = "sum(kube_pod_status_phase{namespace=\"retrogame\", pod=~\"kong.*\", phase=\"Running\"}) == 0"
                  for = "1m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                    service = "kong"
                  }
                  annotations = {
                    summary = "Kong API Gateway not running"
                    description = "No Kong pods are running in namespace retrogame."
                  }
                },
                {
                  alert = "BackendHighCPUUsage"
                  expr = "sum(rate(container_cpu_usage_seconds_total{namespace=\"retrogame\", pod=~\"backend.*\", container!=\"\"}[5m])) by (pod) > 0.8"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                    service = "backend"
                  }
                  annotations = {
                    summary = "Backend high CPU usage"
                    description = "Backend pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} CPU."
                  }
                },
                {
                  alert = "FrontendHighCPUUsage"
                  expr = "sum(rate(container_cpu_usage_seconds_total{namespace=\"retrogame\", pod=~\"frontend.*\", container!=\"\"}[5m])) by (pod) > 0.8"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                    service = "frontend"
                  }
                  annotations = {
                    summary = "Frontend high CPU usage"
                    description = "Frontend pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} CPU."
                  }
                },
                {
                  alert = "KongHighCPUUsage"
                  expr = "sum(rate(container_cpu_usage_seconds_total{namespace=\"retrogame\", pod=~\"kong.*\", container!=\"\"}[5m])) by (pod) > 0.8"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                    service = "kong"
                  }
                  annotations = {
                    summary = "Kong high CPU usage"
                    description = "Kong pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} CPU."
                  }
                },
                {
                  alert = "BackendHighMemoryUsage"
                  expr = "sum(container_memory_usage_bytes{namespace=\"retrogame\", pod=~\"backend.*\", container!=\"\"}) by (pod) > 400000000"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                    service = "backend"
                  }
                  annotations = {
                    summary = "Backend high memory usage"
                    description = "Backend pod {{ $labels.pod }} is using {{ $value | humanize }}B of memory."
                  }
                },
                {
                  alert = "FrontendHighMemoryUsage"
                  expr = "sum(container_memory_usage_bytes{namespace=\"retrogame\", pod=~\"frontend.*\", container!=\"\"}) by (pod) > 256000000"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                    service = "frontend"
                  }
                  annotations = {
                    summary = "Frontend high memory usage"
                    description = "Frontend pod {{ $labels.pod }} is using {{ $value | humanize }}B of memory."
                  }
                },
                {
                  alert = "KongHighMemoryUsage"
                  expr = "sum(container_memory_usage_bytes{namespace=\"retrogame\", pod=~\"kong.*\", container!=\"\"}) by (pod) > 512000000"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                    service = "kong"
                  }
                  annotations = {
                    summary = "Kong high memory usage"
                    description = "Kong pod {{ $labels.pod }} is using {{ $value | humanize }}B of memory."
                  }
                },
                {
                  alert = "RetrogamePodRestartingTooMuch"
                  expr = "increase(kube_pod_container_status_restarts_total{namespace=\"retrogame\"}[1h]) > 3"
                  for = "5m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "Pod {{ $labels.pod }} is restarting frequently"
                    description = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} has restarted {{ $value }} times in the last hour."
                  }
                },
                {
                  alert = "RetrogameTotalRestartsHigh"
                  expr = "sum(kube_pod_container_status_restarts_total{namespace=\"retrogame\"}) > 10"
                  for = "10m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "High total pod restarts in retrogame namespace"
                    description = "Total pod restarts in retrogame namespace is {{ $value }}, indicating instability."
                  }
                },
                {
                  alert = "RetrogameHighNetworkReceive"
                  expr = "sum(rate(container_network_receive_bytes_total{namespace=\"retrogame\"}[5m])) by (pod) > 100000000"
                  for = "10m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "High network receive traffic on {{ $labels.pod }}"
                    description = "Pod {{ $labels.pod }} is receiving {{ $value | humanize }}B/s of network traffic."
                  }
                },
                {
                  alert = "RetrogameHighNetworkTransmit"
                  expr = "sum(rate(container_network_transmit_bytes_total{namespace=\"retrogame\"}[5m])) by (pod) > 100000000"
                  for = "10m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "High network transmit traffic on {{ $labels.pod }}"
                    description = "Pod {{ $labels.pod }} is transmitting {{ $value | humanize }}B/s of network traffic."
                  }
                },
                {
                  alert = "RetrogameDeploymentReplicasMismatch"
                  expr = "kube_deployment_spec_replicas{namespace=\"retrogame\"} != kube_deployment_status_replicas_available{namespace=\"retrogame\"}"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "Deployment {{ $labels.deployment }} has mismatched replicas"
                    description = "Deployment {{ $labels.deployment }} has {{ $value }} unavailable replicas."
                  }
                },
                {
                  alert = "RetrogameServiceDown"
                  expr = "up{namespace=\"retrogame\"} == 0"
                  for = "2m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "Retrogame service {{ $labels.job }} is down"
                    description = "Service {{ $labels.job }} in namespace {{ $labels.namespace }} has been down for more than 2 minutes."
                  }
                },
                {
                  alert = "RetrogamePodCrashLooping"
                  expr = "rate(kube_pod_container_status_restarts_total{namespace=\"retrogame\"}[15m]) > 0.1"
                  for = "5m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "Pod {{ $labels.pod }} is crash looping"
                    description = "Pod {{ $labels.pod }} is restarting frequently ({{ $value }} restarts/min) indicating a crash loop."
                  }
                }
              ]
            },
            {
              name = "retrogame-performance-alerts"
              interval = "30s"
              rules = [
                {
                  alert = "HighRequestLatency"
                  expr = "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace=\"retrogame\"}[5m])) > 1"
                  for = "5m"
                  labels = {
                    severity = "warning"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "High request latency on {{ $labels.service }}"
                    description = "95th percentile latency is {{ $value }}s on service {{ $labels.service }}."
                  }
                },
                {
                  alert = "HighErrorRate"
                  expr = "rate(http_requests_total{namespace=\"retrogame\", status=~\"5..\"}[5m]) / rate(http_requests_total{namespace=\"retrogame\"}[5m]) > 0.05"
                  for = "5m"
                  labels = {
                    severity = "critical"
                    namespace = "retrogame"
                  }
                  annotations = {
                    summary = "High error rate on {{ $labels.service }}"
                    description = "Error rate is {{ $value | humanizePercentage }} on service {{ $labels.service }}."
                  }
                }
              ]
            },
            {
              name = "retrogame-database-alerts"
              interval = "60s"
              rules = [
                {
                  alert = "PostgreSQLDown"
                  expr = "pg_up == 0"
                  for = "2m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary = "PostgreSQL database is down"
                    description = "PostgreSQL instance {{ $labels.instance }} is down."
                  }
                },
                {
                  alert = "PostgreSQLTooManyConnections"
                  expr = "sum(pg_stat_activity_count) > 80"
                  for = "5m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "PostgreSQL has too many connections"
                    description = "PostgreSQL has {{ $value }} active connections."
                  }
                },
                {
                  alert = "PostgreSQLSlowQueries"
                  expr = "rate(pg_stat_statements_mean_exec_time[5m]) > 1000"
                  for = "5m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "PostgreSQL slow queries detected"
                    description = "Average query execution time is {{ $value }}ms."
                  }
                }
              ]
            }
          ]
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
# Outputs movidos a outputs.tf para evitar duplicados
# ============================================================================
