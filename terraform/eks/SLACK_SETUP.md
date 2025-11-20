# 📢 Configuración de Alertas de Slack para AlertManager

## 🎯 Objetivo

Configurar AlertManager para enviar notificaciones de alertas a canales de Slack específicos según la severidad.

## 📋 Prerequisitos

- Acceso de administrador a Slack workspace
- Terraform instalado
- Cluster EKS desplegado

## 🔧 Paso 1: Crear Slack App y Webhook

### 1.1. Crear nueva Slack App

1. Ve a https://api.slack.com/apps
2. Click en **"Create New App"**
3. Selecciona **"From scratch"**
4. Nombre: `Retrogame Monitoring`
5. Workspace: Selecciona tu workspace
6. Click **"Create App"**

### 1.2. Activar Incoming Webhooks

1. En el menú izquierdo, click en **"Incoming Webhooks"**
2. Activa el toggle **"Activate Incoming Webhooks"**
3. Scroll down y click en **"Add New Webhook to Workspace"**
4. Selecciona el canal (por ejemplo `#monitoring-alerts`)
5. Click **"Allow"**
6. **Copia el Webhook URL** (ejemplo: `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX`)

### 1.3. Crear webhooks adicionales para cada canal

Repite el paso 1.2 para cada canal de severidad:

- `#monitoring-alerts` - Alertas generales
- `#critical-alerts` - Alertas críticas
- `#warning-alerts` - Alertas de warning
- `#retrogame-alerts` - Alertas específicas de la aplicación

> **Nota**: Puedes usar el mismo webhook para todos los canales y cambiar el canal en la configuración de AlertManager.

## 🔧 Paso 2: Actualizar monitoring.tf con Webhook URL

### 2.1. Editar monitoring.tf

Abre el archivo `monitoring.tf` y busca la sección de AlertManager:

```hcl
config = {
  global = {
    resolve_timeout = "5m"
    slack_api_url = "SLACK_WEBHOOK_URL_PLACEHOLDER"  # ← REEMPLAZAR AQUÍ
  }
```

Reemplaza `SLACK_WEBHOOK_URL_PLACEHOLDER` con tu webhook URL real:

```hcl
slack_api_url = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
```

### 2.2. (Opcional) Usar Terraform Variables

Para mayor seguridad, usa variables de Terraform:

**variables.tf:**
```hcl
variable "slack_webhook_url" {
  description = "Slack webhook URL for AlertManager notifications"
  type        = string
  sensitive   = true
  default     = ""
}
```

**terraform.tfvars:**
```hcl
slack_webhook_url = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
```

**monitoring.tf:**
```hcl
slack_api_url = var.slack_webhook_url
```

## 🔧 Paso 3: Aplicar cambios

```bash
cd /mnt/c/proyecto_final/infraestructure/terraform/eks_test
terraform plan
terraform apply
```

AlertManager se reconfigurará automáticamente.

## ✅ Paso 4: Probar alertas

### 4.1. Probar alerta manual

```bash
# Port-forward a AlertManager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Enviar alerta de prueba (en otra terminal)
cat <<EOF | curl -X POST -H 'Content-Type: application/json' -d @- http://localhost:9093/api/v1/alerts
[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "namespace": "retrogame"
    },
    "annotations": {
      "summary": "Test alert from AlertManager",
      "description": "This is a test alert to verify Slack integration"
    }
  }
]
EOF
```

Deberías ver un mensaje en tu canal de Slack en ~30 segundos.

### 4.2. Probar alerta real (simular pod down)

```bash
# Escalar deployment a 0 replicas
kubectl scale deployment/backend -n retrogame --replicas=0

# Esperar 2-3 minutos, verás alerta: "RetrogamePodDown"

# Restaurar deployment
kubectl scale deployment/backend -n retrogame --replicas=1
```

## 📊 Canales de Slack y Severidades

| Canal | Severidad | Alertas |
|-------|-----------|---------|
| `#monitoring-alerts` | info | Alertas generales |
| `#critical-alerts` | critical | Pods down, servicios caídos, alta tasa de errores |
| `#warning-alerts` | warning | CPU alto, memoria alta, latencia |
| `#retrogame-alerts` | info | Alertas específicas de la app |

## 🎨 Personalizar mensajes de Slack

Edita la sección `slack_configs` en `monitoring.tf`:

```hcl
slack_configs = [
  {
    channel = "#monitoring-alerts"
    title = "🔔 [{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}"
    text = "{{ range .Alerts }}*Alert:* {{ .Annotations.summary }}\n*Description:* {{ .Annotations.description }}\n{{ end }}"
    send_resolved = true
    color = "{{ if eq .Status \"firing\" }}danger{{ else }}good{{ end }}"
    
    # Campos personalizados
    fields = [
      {
        title = "Environment"
        value = "Production"
        short = true
      },
      {
        title = "Namespace"
        value = "{{ .GroupLabels.namespace }}"
        short = true
      }
    ]
  }
]
```

## 📖 Referencias

- [AlertManager Slack Configuration](https://prometheus.io/docs/alerting/latest/configuration/#slack_config)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [AlertManager Template Examples](https://prometheus.io/docs/alerting/latest/notification_examples/)

## 🐛 Troubleshooting

### No recibo alertas en Slack

1. **Verificar webhook URL:**
   ```bash
   kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o yaml
   ```

2. **Ver logs de AlertManager:**
   ```bash
   kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0
   ```

3. **Verificar configuración:**
   ```bash
   kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o json | \
     jq -r '.data["alertmanager.yaml"]' | base64 -d
   ```

4. **Verificar estado de alertas:**
   ```bash
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
   # Abrir en navegador: http://localhost:9093
   ```

### AlertManager no arranca

```bash
# Ver eventos
kubectl describe pod -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0

# Ver logs
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager
```

## 🎉 ¡Listo!

Ahora tu cluster enviará alertas automáticamente a Slack cuando:
- Un pod esté down
- CPU/Memoria alta
- Errores en la aplicación
- Base de datos caída
- Y mucho más...
