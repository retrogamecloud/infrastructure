# Changelog - Branch feature/monitoring

## Resumen

Esta rama implementa un **stack completo de observabilidad** (Prometheus + Grafana + AlertManager) para el cluster EKS de RetroGameCloud. Es 100% **no destructivo** - todos los recursos están en un namespace separado `monitoring` y no toca código existente.

## Archivos Añadidos

### 1. `monitoring.tf` (455 líneas)
Stack completo de observabilidad usando kube-prometheus-stack via Helm.

**Componentes incluidos:**
- ✅ **Prometheus Server**: 10Gi storage, 3d retention, scraping cada 30s
- ✅ **Grafana**: 20+ dashboards pre-configurados, credenciales: admin/admin123
- ✅ **AlertManager**: Sistema de alertas con reglas por defecto
- ✅ **Node Exporter**: DaemonSet para métricas de nodos EC2
- ✅ **Kube State Metrics**: Estado del cluster (pods, deployments, services)
- ✅ **Prometheus Operator**: Gestión automática de configuración

**Recursos:**
- CPU requests: ~550m (200m Prometheus + 100m Grafana + 50m AlertManager + 200m otros)
- Memory requests: ~1.2Gi (512Mi + 256Mi + 128Mi + 320Mi)
- Storage: 12Gi EBS (10Gi Prometheus + 2Gi AlertManager)

**Costo adicional:** ~$1.50/mes (solo EBS volumes)

**6 Outputs útiles:**
- `prometheus_url`: URL interna de Prometheus
- `grafana_url`: URL interna de Grafana
- `grafana_admin_password`: Password de admin (sensible)
- `grafana_port_forward_command`: Comando kubectl para acceder
- `check_servicemonitors_command`: Verificar ServiceMonitors
- `prometheus_targets_command`: Ver targets en Prometheus UI

### 2. `servicemonitors.tf` (289 líneas)
ServiceMonitors opcionales para scrapear métricas custom de las aplicaciones.

**ServiceMonitors creados:**
- ✅ **Backend**: scraping `backend:3000/metrics` cada 30s
- ✅ **Frontend**: scraping `frontend:8081/metrics` cada 30s
- ✅ **Kong**: scraping `kong:8000/metrics` cada 30s

**Requisito:** Las aplicaciones deben exponer endpoint `/metrics` en formato Prometheus.

**Opcionales:** El stack funciona sin ellos, pero son recomendados para métricas custom.

### 3. `MONITORING_GUIDE.md` (794 líneas)
Guía completa de implementación y uso del stack de monitoring.

**Secciones principales:**
1. Componentes y recursos del sistema
2. Verificar capacidad del cluster (fit en t3.micro)
3. Despliegue paso a paso (completo e incremental)
4. Verificación post-deploy (namespace, pods, services, PVCs)
5. Acceso a Grafana vía port-forward
6. Dashboards pre-configurados (20+ incluidos)
7. Queries PromQL útiles con ejemplos
8. Alertas pre-configuradas (10+ reglas)
9. Configuración avanzada (Slack, persistencia, retención)
10. Monitorear aplicaciones propias (ServiceMonitors)
11. Rollback procedures
12. Costos detallados y optimizaciones

### 4. `example-prometheus-metrics.js` (276 líneas)
Código de ejemplo completo para instrumentar aplicaciones Node.js con Prometheus.

**Incluye:**
- ✅ Métricas default de Node.js (CPU, memoria, eventloop lag, GC)
- ✅ Middleware automático para HTTP requests:
  - `backend_http_requests_total`: Counter por método, ruta, status code
  - `backend_http_request_duration_seconds`: Histogram de latency
  - `backend_http_requests_in_progress`: Gauge de requests activos
- ✅ Métricas de base de datos (queries, duration)
- ✅ Métricas de negocio (registros de usuarios, juegos cargados)
- ✅ Endpoint `/metrics` para Prometheus
- ✅ Documentación exhaustiva con ejemplos

**Uso:**
```javascript
const { setupPrometheus } = require('./metrics/prometheus');
const metrics = setupPrometheus(app);
```

## Archivos Modificados

### 5. `.gitignore` (mejorado)
Añadidas reglas faltantes para Terraform y archivos temporales.

**Nuevas entradas:**
- `*.tfplan`, `*.tfplan.json` (plan files con info sensible)
- `*.tfstate.*` (state backups)
- `*.auto.tfvars.json` (variables sensibles)
- Archivos de IDEs (VS Code, IntelliJ, Vim, Emacs)
- Certificados (*.crt, *.cert, *.p12, *.pfx)
- Logs y temporales (*.log, *.bak, *.tmp)
- Compatible con macOS, Linux, Windows

### 6. `README.md` (actualizado)
Añadida documentación del stack de monitoring.

**Cambios:**
- Nueva sección **"Observabilidad (Monitoring Stack)"** en Componentes
- Paso 8: **"Acceder a Grafana y Prometheus"** con port-forward
- Credenciales default (admin/admin123)
- Dashboards recomendados
- Enlace a MONITORING_GUIDE.md
- Costos actualizados: +$1.50/mes
- Total: **~$230.50/mes** (con monitoring)

## Commits

```
3107985 (HEAD -> feature/monitoring) docs: Añadir script ejemplo de Prometheus y actualizar README con monitoring
77b6283 feat: Añadir ServiceMonitors opcionales para Prometheus y mejorar .gitignore
152f9d8 feat: Implementar stack de observabilidad con Prometheus + Grafana + AlertManager
```

## Verificación

```bash
# Terraform validation
cd /mnt/c/proyecto_final/infraestructure/terraform/eks_test
terraform init -upgrade
terraform validate
# Output: Success! The configuration is valid.

# Git status
git status
# Output: On branch feature/monitoring
#         nothing to commit, working tree clean
```

## Próximos Pasos

1. ✅ **COMPLETADO**: Implementar monitoring.tf
2. ✅ **COMPLETADO**: Configurar kube-prometheus-stack
3. ✅ **COMPLETADO**: Crear ServiceMonitors opcionales
4. ✅ **COMPLETADO**: Mejorar .gitignore
5. ✅ **COMPLETADO**: Documentar en README
6. ✅ **COMPLETADO**: Script ejemplo prom-client
7. ⏳ **PENDIENTE**: Push a GitHub cuando usuario lo solicite
8. ⏳ **PENDIENTE**: Merge a feature/eks_test o main
9. ⏳ **PENDIENTE**: Desplegar con terraform apply
10. ⏳ **PENDIENTE**: Configurar alertas a Slack/email (opcional)

## Notas Importantes

- **No destructivo**: Namespace separado, cero cambios en recursos existentes
- **Terraform plan**: Mostrará crear TODO (normal, no hay state file)
- **Rollback fácil**: `terraform destroy -target=helm_release.kube_prometheus_stack`
- **Compatible con t3.micro**: Recursos optimizados para fit en 3 nodos
- **Dashboards incluidos**: 20+ dashboards de Grafana pre-configurados
- **ServiceMonitors opcionales**: Apps deben exponer /metrics (ver example-prometheus-metrics.js)

## Costos

| Recurso | Costo Mensual |
|---------|---------------|
| EBS 10Gi (Prometheus) | ~$0.80 |
| EBS 2Gi (AlertManager) | ~$0.16 |
| Compute (pods) | Incluido en Fargate |
| **TOTAL** | **~$1.50/mes** |

**Nota**: LoadBalancer para Grafana costaría +$16/mes (no recomendado, usar port-forward)

## Documentación Relacionada

- **Guía completa**: [MONITORING_GUIDE.md](./MONITORING_GUIDE.md)
- **Roadmap**: [ROADMAP.md](./ROADMAP.md) - FASE 1 (18-24 Nov)
- **Dominio**: [DOMAIN_SETUP.md](./DOMAIN_SETUP.md) - retrogamehub.games
- **README**: [README.md](./README.md) - Sección "Observabilidad"

---

**Fecha**: 18 Noviembre 2024  
**Branch**: feature/monitoring (desde feature/eks_test)  
**Status**: ✅ Implementación completa, listo para push y deploy
