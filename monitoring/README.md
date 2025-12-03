# Infraestructura de Monitoreo

## Descripción

La stack de monitoreo proporciona observabilidad completa del cluster de Kubernetes y las aplicaciones desplegadas en RetroGame. Integra Grafana, Prometheus y Alertmanager para visualización de métricas, alertas y gestión de incidentes. Incluye autenticación mediante GitHub OAuth y dashboards personalizados para el seguimiento de Backend, Frontend, Kong y la infraestructura de Kubernetes.

## Tabla de contenidos

- [Descripción](#descripción)
- [Funcionalidad](#funcionalidad)
- [Stack tecnológico](#stack-tecnológico)
- [Guía de despliegue](#guía-de-despliegue)
- [Personalización y configuración](#personalización-y-configuración)
- [Seguridad](#seguridad)

## Funcionalidad

### Componentes principales

**Grafana**
- Visualización de métricas en tiempo real
- Dashboards personalizados para RetroGame Platform
- Autenticación GitHub OAuth para acceso seguro
- 22 paneles monitorean Backend, Frontend, Kong, Prometheus, Alertmanager e NGINX Ingress
- Almacenamiento efímero (persistencia deshabilitada por diseño)
- Gestión de roles: Admin automático para maintainers, Viewer para otros usuarios

**Prometheus**
- Recolección de métricas de Kubernetes (API Server, etcd, kubelet)
- Métricas de aplicaciones vía Prometheus Operator
- Retención de 3 días para histórico comprimido
- Almacenamiento en volumen persistente (10GB gp2)
- Exportadores: node-exporter, kube-state-metrics
- Alertas basadas en umbrales y reglas de negocio

**Alertmanager**
- Enrutamiento de alertas desde Prometheus
- Integraciones de notificación (Slack, email, webhooks)
- Gestión de silenciadores y agrupamiento inteligente
- Almacenamiento efímero

**Sidecar de Dashboards**
- Carga automática de dashboards desde ConfigMaps
- Label selector: `grafana_dashboard=1`
- Namespace: monitoring
- Carpeta destino: "RetroGame Platform"

### Métricas monitoreadas

**Backend (namespace: retrogame)**
- CPU por pod (rate 5m)
- Memoria por pod
- Pods activos en estado Running
- Reinicios totales de containers

**Frontend (namespace: retrogame)**
- CPU por pod
- Memoria por pod

**Kong API Gateway (namespace: retrogame)**
- CPU por pod
- Memoria por pod

**Infraestructura**
- Tráfico de red (RX/TX) por pod
- Estado de pods (tabla completa)
- Reinicios de containers por pod
- Prometheus: CPU y memoria
- Alertmanager: CPU y memoria
- NGINX Ingress Controller: CPU y memoria

**Indicadores globales**
- Uso promedio de CPU del cluster (%)
- Alertas activas (count)

## Stack tecnológico

| Componente | Versión | Propósito |
|-----------|---------|----------|
| kube-prometheus-stack | Latest Helm | Stack completa monitoring |
| Grafana | 10.2.2+ | Visualización y dashboards |
| Prometheus | Latest (3d retention) | Recolección de métricas |
| Alertmanager | Latest | Gestión de alertas |
| Node Exporter | Latest | Métricas de nodos |
| kube-state-metrics | Latest | Estado de Kubernetes |
| Prometheus Operator | Latest | Operador de reglas/servicios |
| NGINX Ingress Controller | Latest | Ingress para Grafana, Prometheus, Alertmanager |
| Kubernetes | 1.28+ | Orquestación |
| GitHub OAuth | v2 | Autenticación segura |

## Guía de despliegue

### Prerrequisitos

- Cluster Kubernetes 1.28+
- Helm 3.x
- kubectl configurado
- Namespace `monitoring` creado
- Credenciales GitHub OAuth App:
  - Client ID
  - Client Secret
  - Authorized callback URL: `https://retrogamehub.games/grafana/login/github`

### Paso 1: Crear credenciales GitHub OAuth

Generar Client ID y Secret en GitHub:
1. Ir a Settings → Developer settings → OAuth Apps → New OAuth App
2. Application name: `RetroGame Monitoring`
3. Homepage URL: `https://retrogamehub.games`
4. Authorization callback URL: `https://retrogamehub.games/grafana/login/github`
5. Copiar Client ID y Client Secret

### Paso 2: Crear Secret con credenciales

```bash
kubectl create namespace monitoring

# Codificar credenciales en base64
echo -n "YOUR_CLIENT_ID" | base64
echo -n "YOUR_CLIENT_SECRET" | base64
echo -n "admin-user" | base64
echo -n "admin-password" | base64

# Aplicar secret
kubectl apply -f grafana-github-oauth-secret.yaml
```

**Estructura del Secret** (grafana-github-oauth-secret.yaml):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-github-oauth
  namespace: monitoring
type: Opaque
data:
  GF_AUTH_GITHUB_CLIENT_ID: <base64_encoded>
  GF_AUTH_GITHUB_CLIENT_SECRET: <base64_encoded>
  admin-user: YWRtaW4=
  admin-password: <base64_encoded>
```

### Paso 3: Desplegar kube-prometheus-stack

```bash
# Agregar repositorio Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Desplegar con valores personalizados
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f grafana-values.yaml

# Verificar despliegue
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

### Paso 4: Aplicar ConfigMap con dashboard

```bash
kubectl apply -f retrogame-dashboard-configmap.yaml

# Verificar que Grafana cargó el dashboard
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f
```

### Paso 5: Exponer servicios

```bash
# Verificar ingress o port-forward
kubectl get ingress -n monitoring

# Alternativa con port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Acceder: http://localhost:3000
```

### Paso 6: Validar acceso

1. Navegar a `https://retrogamehub.games/grafana`
2. Hacer login con GitHub
3. Verificar que el usuario tiene rol Admin (si está en lista autorizada)
4. Acceder a Dashboard: "Retrogame - Aplicación Completa"
5. Verificar paneles y métricas

### Resumen de comandos

```bash
# 1. Namespace
kubectl create namespace monitoring

# 2. Secret OAuth
kubectl apply -f grafana-github-oauth-secret.yaml

# 3. Stack Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f grafana-values.yaml

# 4. Dashboard ConfigMap
kubectl apply -f retrogame-dashboard-configmap.yaml

# 5. Acceso
# Por ingress: https://retrogamehub.games/grafana
# O port-forward: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

## Personalización y configuración

### Agregar reglas de alertas

Las reglas se definen en PrometheusRule CRD (no incluido en este directorio, agregar si es necesario).

Ejemplo de estructura:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: retrogame-alerts
  namespace: monitoring
spec:
  groups:
  - name: retrogame.rules
    interval: 30s
    rules:
    - alert: HighPodCPU
      expr: sum(rate(container_cpu_usage_seconds_total[5m])) > 0.8
      for: 5m
```

## Seguridad

### Gestión de credenciales

**GitHub OAuth**
- Client ID y Secret almacenados en Secret de Kubernetes
- Nunca exponerlos en documentación o logs
- Rotarlos cada 90 días o ante sospecha de compromiso
- Revocar en GitHub Settings si se comprometen

**Admin credentials**
- Almacenados en Secret: `grafana-github-oauth` (campos admin-user, admin-password)
- Cambiar password en Grafana UI después del despliegue inicial
- Usar solo para emergencias si GitHub OAuth falla

```bash
# Rotar credenciales
echo -n "new-admin-password" | base64
kubectl patch secret grafana-github-oauth -n monitoring --type merge \
  -p '{"data":{"admin-password":"<new-base64>"}}'

# Reiniciar Grafana
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring
```

### Control de acceso (RBAC)

**ServiceAccounts Prometheus**
```yaml
# Solo lectura de métricas
- apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRole
  metadata:
    name: prometheus-metrics-reader
  rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"]
    verbs: ["list", "watch"]
```

**Usuarios Grafana**
- Admin: jpalenz77, naesman1, evaristogz (hardcodeado en role_attribute_path)
- Viewer: resto de usuarios autenticados por GitHub
- Cambiar lista en grafana-values.yaml y redeploy

```yaml
role_attribute_path: "contains(login, 'jpalenz77') && 'Admin' || contains(login, 'naesman1') && 'Admin' || contains(login, 'evaristogz') && 'Admin' || 'Viewer'"
```

### Comunicación segura

**TLS/HTTPS obligatorio**
- Ingress requiere certificado TLS (Let's Encrypt)
- Grafana config: `cookie_secure: false` (proxy termina TLS)
- Prometheus/Alertmanager: acceso solo via HTTPS del ingress

```yaml
# Ingress debe tener certificado
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
spec:
  tls:
  - hosts:
    - retrogamehub.games
    secretName: retrogame-tls-cert
```

### Auditoría

**Logs de Grafana**
```bash
# Ver cambios en dashboards y usuarios
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana | grep "login\|dashboard"
```

**Métricas de acceso Prometheus**
```promql
# Conexiones exitosas
sum(increase(prometheus_http_requests_total{handler="query"}[5m])) by (job)

# Errores de autenticación
sum(increase(prometheus_http_request_duration_seconds_bucket{le="0.1"}[5m]))
```

### Almacenamiento de datos

**Prometheus**
- PVC gp2 de 10GB con retención 3d
- Datos no están encriptados en storage (configurar si es sensible)
- No incluir información PII en etiquetas de métricas

**Grafana**
- Persistencia deshabilitada (ephemeral)
- Configuración se recarga desde ConfigMap cada reinicio
- No almacena datos sensibles en BD local

**Recomendación:** Encriptar PVC con LUKS o proveedores de storage encriptado:
```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp2-encrypted  # requiere storage class con encriptación
```
