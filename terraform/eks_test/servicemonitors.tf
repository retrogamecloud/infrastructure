# ============================================================================
# ServiceMonitors - Monitoreo de Aplicaciones
# ============================================================================
#
# ServiceMonitors son CRDs (Custom Resource Definitions) de Prometheus Operator
# que le dicen a Prometheus qué endpoints debe "scrapear" (recolectar métricas).
#
# IMPORTANTE: 
# - Para que estos funcionen, tus aplicaciones deben exponer métricas en /metrics
# - Ver MONITORING_GUIDE.md sección "Monitorear Aplicaciones Propias"
# - Estos son OPCIONALES - el stack funciona sin ellos
#
# ============================================================================

# ============================================================================
# ServiceMonitor para Backend
# ============================================================================
# 
# Requisito: Backend debe exponer /metrics en puerto 3000
# Ejemplo: GET http://backend:3000/metrics
# Formato: Prometheus text format (usar biblioteca prom-client)
#
# Ejemplo de implementación en backend (Node.js):
# ```javascript
# const promClient = require('prom-client');
# promClient.collectDefaultMetrics();
# app.get('/metrics', async (req, res) => {
#   res.set('Content-Type', promClient.register.contentType);
#   res.end(await promClient.register.metrics());
# });
# ```
# ============================================================================

resource "kubernetes_manifest" "backend_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "backend"
      namespace = "retrogame"
      labels = {
        app     = "backend"
        release = "kube-prometheus-stack"  # Importante: Prometheus busca este label
      }
    }
    spec = {
      # Selector: busca Services con label app=backend
      selector = {
        matchLabels = {
          app = "backend"
        }
      }
      
      # Endpoints a scrapear
      endpoints = [
        {
          port     = "http"        # Nombre del puerto en el Service (debe ser "http" o ajustar)
          path     = "/metrics"    # Endpoint de métricas
          interval = "30s"         # Frecuencia de scraping
          scrapeTimeout = "10s"    # Timeout por scrape
        }
      ]
    }
  }

  # Dependencia: ServiceMonitor requiere que el CRD exista (instalado por Prometheus Operator)
  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# ============================================================================
# ServiceMonitor para Frontend
# ============================================================================
# 
# Requisito: Frontend debe exponer /metrics en puerto 8081
# El frontend de Node.js puede exponer métricas básicas de Express
# ============================================================================

resource "kubernetes_manifest" "frontend_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "frontend"
      namespace = "retrogame"
      labels = {
        app     = "frontend"
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "frontend"
        }
      }
      
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# ============================================================================
# ServiceMonitor para Kong API Gateway
# ============================================================================
# 
# Kong tiene un plugin de Prometheus que expone métricas en /metrics
# Por defecto Kong no lo tiene habilitado, pero se puede configurar
# 
# Para habilitar en Kong:
# 1. Instalar plugin prometheus en Kong
# 2. Configurar plugin a nivel global o por route/service
# 
# Ver: https://docs.konghq.com/hub/kong-inc/prometheus/
# ============================================================================

resource "kubernetes_manifest" "kong_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "kong"
      namespace = "retrogame"
      labels = {
        app     = "kong"
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "kong"
        }
      }
      
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# ============================================================================
# Outputs para debugging de ServiceMonitors
# ============================================================================

output "servicemonitors_created" {
  description = "Lista de ServiceMonitors creados"
  value = [
    "backend - scraping backend:3000/metrics cada 30s",
    "frontend - scraping frontend:8081/metrics cada 30s",
    "kong - scraping kong:8000/metrics cada 30s"
  ]
}

output "check_servicemonitors_command" {
  description = "Comando para verificar ServiceMonitors"
  value       = "kubectl get servicemonitors -n retrogame"
}

output "check_prometheus_targets_command" {
  description = "Comando para ver targets en Prometheus"
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 && open http://localhost:9090/targets"
}
