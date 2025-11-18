# 📊 Monitoring Stack - Guía de Implementación

## 🎯 Objetivo

Implementar Prometheus + Grafana + AlertManager en el cluster EKS de forma **NO DESTRUCTIVA** y **modular**.

## ✅ Lo que se implementa

### Componentes Nuevos (Namespace: monitoring)

- **Prometheus Operator**: Gestiona Prometheus, AlertManager y ServiceMonitors
- **Prometheus Server**: Recolección de métricas (3 días de retención)
- **Grafana**: Visualización con dashboards pre-configurados
- **AlertManager**: Gestión de alertas
- **Node Exporter**: DaemonSet que recolecta métricas de cada nodo EC2
- **Kube State Metrics**: Métricas del estado de Kubernetes

### Recursos de Sistema

| Componente | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Prometheus Server | 200m | 512Mi | 500m | 1Gi |
| Grafana | 100m | 256Mi | 200m | 512Mi |
| AlertManager | 50m | 128Mi | 100m | 256Mi |
| Node Exporter | 50m | 64Mi | 100m | 128Mi |
| Kube State Metrics | 50m | 128Mi | 100m | 256Mi |
| Prometheus Operator | 100m | 128Mi | 200m | 256Mi |
| **TOTAL** | **~550m** | **~1.2Gi** | **~1.2 vCPU** | **~2.4Gi** |

**Capacidad disponible en 3x t3.micro:**
- Total: 6 vCPU, ~2.5GB RAM usable
- Usado por apps actuales: ~300m CPU, ~512MB RAM
- **Espacio para monitoring**: ✅ SÍ, cabe cómodamente

## 🚀 Despliegue

### Opción 1: Despliegue Completo (Recomendado)

```bash
cd /mnt/c/proyecto_final/infraestructure/terraform/eks_test

# 1. Inicializar (si no lo has hecho)
terraform init

# 2. Plan - Verificar que solo añade recursos
terraform plan

# Deberías ver:
# Plan: XX to add, 0 to change, 0 to destroy
# ↑ IMPORTANTE: 0 to change, 0 to destroy

# 3. Aplicar
terraform apply

# Tiempo estimado: 5-8 minutos
```

### Opción 2: Despliegue Incremental (Más Seguro)

```bash
# Paso 1: Solo el namespace (0 riesgo)
terraform apply -target=kubernetes_namespace.monitoring

# Paso 2: Instalar stack completo
terraform apply -target=helm_release.kube_prometheus_stack

# Tiempo por paso:
# - Namespace: <1 segundo
# - Helm release: 5-8 minutos
```

## ✅ Verificación Post-Deploy

### 1. Verificar Namespace

```bash
kubectl get namespace monitoring

# Output esperado:
# NAME         STATUS   AGE
# monitoring   Active   10s
```

### 2. Verificar Pods

```bash
kubectl get pods -n monitoring

# Output esperado (después de 5-8 min):
# NAME                                                     READY   STATUS
# alertmanager-kube-prometheus-stack-alertmanager-0       2/2     Running
# kube-prometheus-stack-grafana-xxxxxxxxxx-xxxxx          3/3     Running
# kube-prometheus-stack-kube-state-metrics-xxxxx          1/1     Running
# kube-prometheus-stack-operator-xxxxxxxxxx-xxxxx         1/1     Running
# kube-prometheus-stack-prometheus-node-exporter-xxxxx    1/1     Running (x3)
# prometheus-kube-prometheus-stack-prometheus-0           2/2     Running
```

**Si ves pods en Pending:**
```bash
# Ver detalles
kubectl describe pod <pod-name> -n monitoring

# Causa común: Recursos insuficientes
# Solución: Escalar node group o reducir resources en monitoring.tf
```

### 3. Verificar Services

```bash
kubectl get svc -n monitoring

# Output esperado:
# kube-prometheus-stack-alertmanager       ClusterIP   10.0.x.x    9093/TCP
# kube-prometheus-stack-grafana            ClusterIP   10.0.x.x    80/TCP
# kube-prometheus-stack-prometheus         ClusterIP   10.0.x.x    9090/TCP
# ...
```

## 🌐 Acceder a Grafana

### Opción 1: Port Forward (Desarrollo)

```bash
# Terminal 1: Port forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Terminal 2: Abrir en navegador
# Linux/WSL:
open http://localhost:3000

# Windows:
start http://localhost:3000

# Credenciales:
# Usuario: admin
# Password: admin123 (cambiar en producción!)
```

### Opción 2: Crear LoadBalancer (Producción - Cuesta ~$16/mes)

Editar `monitoring.tf` y cambiar:

```hcl
grafana = {
  service = {
    type = "LoadBalancer"  # Cambiado de ClusterIP
    port = 80
  }
}
```

Luego:
```bash
terraform apply

# Obtener URL del LoadBalancer
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# EXTERNAL-IP será la URL pública
```

## 📊 Dashboards Incluidos

Grafana viene con ~20 dashboards pre-configurados:

1. **Kubernetes / Compute Resources / Cluster** - Vista general del cluster
2. **Kubernetes / Compute Resources / Namespace (Pods)** - Por namespace
3. **Kubernetes / Compute Resources / Node (Pods)** - Por nodo EC2
4. **Kubernetes / Compute Resources / Pod** - Detalle de pod individual
5. **Kubernetes / Networking / Cluster** - Tráfico de red
6. **Node Exporter / Nodes** - Métricas de EC2 (CPU, RAM, disk, network)
7. **Prometheus / Overview** - Estado de Prometheus
8. **AlertManager / Overview** - Alertas activas

### Explorar Dashboards:

1. Login a Grafana (admin/admin123)
2. Click en "Dashboards" (icono de cuatro cuadrados)
3. Navegar por carpetas:
   - General
   - Kubernetes
   - Prometheus

## 🔍 Queries Útiles en Prometheus

Acceder a Prometheus:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Abrir: http://localhost:9090
```

### Ejemplos de Queries (PromQL):

```promql
# CPU usage por pod
sum(rate(container_cpu_usage_seconds_total{namespace="retrogame"}[5m])) by (pod)

# Memory usage por pod
sum(container_memory_working_set_bytes{namespace="retrogame"}) by (pod)

# Request rate del backend
rate(http_requests_total{job="backend"}[5m])

# Pods running
kube_pod_status_phase{namespace="retrogame",phase="Running"}

# Node CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node Memory usage %
100 * (1 - ((node_memory_MemAvailable_bytes) / (node_memory_MemTotal_bytes)))
```

## 🚨 Alertas Básicas Incluidas

AlertManager viene con alertas pre-configuradas:

- **KubePodCrashLooping** - Pod en crash loop
- **KubePodNotReady** - Pod no Ready por >15 min
- **KubeNodeNotReady** - Nodo EC2 no Ready
- **KubeMemoryOvercommit** - Cluster sin memoria suficiente
- **KubeCPUOvercommit** - Cluster sin CPU suficiente
- **PrometheusDown** - Prometheus caído
- **PrometheusTSDBCompactionsFailing** - Problemas de storage

Ver alertas activas:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Abrir: http://localhost:9093
```

## 🔧 Configuración Avanzada (Opcional)

### Añadir Notificaciones Slack

Editar `monitoring.tf`, sección AlertManager config:

```hcl
config = {
  global = {
    resolve_timeout = "5m"
    slack_api_url   = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
  }
  route = {
    receiver = "slack"
  }
  receivers = [
    {
      name = "slack"
      slack_configs = [
        {
          channel  = "#alerts"
          username = "AlertManager"
          icon_url = "https://example.com/icon.png"
          title    = "{{ .GroupLabels.alertname }}"
          text     = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
        }
      ]
    }
  ]
}
```

### Añadir Persistencia a Grafana

```hcl
grafana = {
  persistence = {
    enabled      = true
    size         = "5Gi"
    storageClass = "gp2"  # EBS en AWS
  }
}
```

### Aumentar Retención de Prometheus

```hcl
prometheus = {
  prometheusSpec = {
    retention = "7d"  # Cambiado de 3d a 7d
    
    storageSpec = {
      volumeClaimTemplate = {
        spec = {
          resources = {
            requests = {
              storage = "20Gi"  # Cambiado de 10Gi a 20Gi
            }
          }
        }
      }
    }
  }
}
```

## 📈 Monitorear Aplicaciones Propias

Para que Prometheus recolecte métricas de tus aplicaciones (backend, frontend, kong), necesitas:

### 1. Exponer métricas en tu app

**Backend (Node.js + Express):**
```javascript
// npm install prom-client
const promClient = require('prom-client');

// Registrar métricas default
promClient.collectDefaultMetrics();

// Endpoint /metrics
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

### 2. Crear ServiceMonitor

Crear archivo `servicemonitors.tf`:

```hcl
# ServiceMonitor para Backend
resource "kubernetes_manifest" "backend_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "backend"
      namespace = "retrogame"
      labels = {
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "backend"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}
```

### 3. Aplicar

```bash
terraform apply -target=kubernetes_manifest.backend_servicemonitor
```

### 4. Verificar en Prometheus

```
# Query para verificar scraping
up{job="backend"}

# Debe retornar: 1 (UP)
```

## 🗑️ Rollback / Eliminar Monitoring

Si necesitas eliminar todo el stack de monitoring:

```bash
# Eliminar todo monitoring (sin afectar tus apps)
terraform destroy -target=helm_release.kube_prometheus_stack
terraform destroy -target=kubernetes_namespace.monitoring

# O eliminar solo Grafana
kubectl delete deployment kube-prometheus-stack-grafana -n monitoring
```

## 💰 Costos Adicionales

| Recurso | Costo Mensual |
|---------|---------------|
| EBS Volumes (Prometheus 10Gi + AlertManager 2Gi) | ~$1.50 |
| Data transfer (dentro de VPC) | Gratis |
| LoadBalancer para Grafana (opcional) | +$16 |
| **TOTAL (sin LB)** | **~$1.50/mes** |
| **TOTAL (con LB)** | **~$17.50/mes** |

**Recomendación**: Usar port-forward para dev, LoadBalancer solo en prod.

## 📚 Recursos Útiles

- [Prometheus Operator Docs](https://prometheus-operator.dev/)
- [Grafana Dashboards Library](https://grafana.com/grafana/dashboards/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Kube-Prometheus-Stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [AlertManager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)

## ✅ Checklist de Implementación

- [ ] Terraform init ejecutado
- [ ] Terraform plan verificado (0 to change, 0 to destroy)
- [ ] Terraform apply completado sin errores
- [ ] Namespace monitoring creado
- [ ] Todos los pods en estado Running
- [ ] Port-forward a Grafana funcionando
- [ ] Login a Grafana exitoso (admin/admin123)
- [ ] Dashboards de Kubernetes visibles
- [ ] Port-forward a Prometheus funcionando
- [ ] Queries básicas de PromQL funcionando
- [ ] AlertManager accesible
- [ ] ServiceMonitors configurados (opcional)
- [ ] Documentación actualizada
- [ ] Commit y push a feature/monitoring

## 🎯 Próximos Pasos

Una vez que el monitoring esté funcionando:

1. **Configurar alertas a Slack/Email** - Ver sección "Configuración Avanzada"
2. **Crear dashboards custom** - Para tus métricas específicas
3. **Implementar ServiceMonitors** - Para backend, frontend, kong
4. **Exponer Grafana con dominio** - `grafana.retrogamehub.games`
5. **Configurar SSL/HTTPS** - Certificado ACM + Ingress
6. **Implementar Loki** - Para logs centralizados (opcional)
