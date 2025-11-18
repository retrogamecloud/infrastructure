# RetroGameCloud - EKS Deployment con Terraform

Este directorio contiene la infraestructura como código (IaC) para desplegar RetroGameCloud en AWS usando EKS (Elastic Kubernetes Service).

## Arquitectura

- **VPC**: Red privada virtual con subnets públicas y privadas en 3 Availability Zones
- **EKS Cluster**: Kubernetes v1.32 con Node Groups EC2
- **RDS PostgreSQL**: Base de datos gestionada (PostgreSQL 15.15)
- **S3 + CloudFront**: CDN para archivos estáticos (juegos .jsdos, imágenes, emulador)
- **Load Balancer**: Network Load Balancer (NLB) para Kong API Gateway
- **Security Groups**: Aislamiento de red entre componentes
- **Auto-deploy**: Scripts automáticos para inicialización de BD y subida de assets

### ¿Por qué EC2 Node Groups?

✅ **Mayor estabilidad** - Control completo sobre los nodos de computación
✅ **Más económico** - ~$205/mes vs $229 con Fargate
✅ **Mejor rendimiento** - Networking más rápido con ENIs dedicadas
✅ **Persistencia** - Nodos dedicados sin cold starts
✅ **Flexibilidad** - Elección de instance types y configuraciones personalizadas

## Componentes

### Infraestructura AWS
- `provider.tf`: Configuración de providers (AWS, Kubernetes, Helm, Null)
- `variables.tf`: Variables configurables
- `eks.tf`: Cluster EKS v1.32, VPC, Node Groups, Security Groups
- `rds.tf`: RDS PostgreSQL con credenciales en Kubernetes Secret
- `s3-cdn.tf`: S3 Buckets (CDN + logs), CloudFront, auto-upload de assets
- `outputs.tf`: Outputs útiles post-despliegue

### Aplicaciones Kubernetes
- `kubernetes.tf`: Deployments, Services, ConfigMaps, Secrets, Jobs
  - Backend (1 réplica) - 100m CPU, 256MB RAM
  - Frontend (1 réplica) - 50m CPU, 128MB RAM con init containers para URL replacement
  - Kong API Gateway (1 réplica) - 100m CPU, 256MB RAM
  - Job de inicialización de BD (automático)
  - Null resource para actualización de URLs post-deploy

### Observabilidad (Monitoring Stack)
- `monitoring.tf`: Stack completo de Prometheus + Grafana + AlertManager
  - **Prometheus**: Time-series database para métricas (10Gi storage, 3d retention)
  - **Grafana**: Dashboards interactivos pre-configurados (20+ dashboards incluidos)
  - **AlertManager**: Sistema de alertas con notificaciones configurables
  - **Node Exporter**: Métricas de nodos EC2 (CPU, memoria, disco, red)
  - **Kube State Metrics**: Estado del cluster (pods, deployments, services)
  - Namespace separado `monitoring` (no intrusivo)
- `servicemonitors.tf`: Configuración para scrapear métricas de aplicaciones propias
  - ServiceMonitor para Backend (/metrics cada 30s)
  - ServiceMonitor para Frontend (/metrics cada 30s)
  - ServiceMonitor para Kong (/metrics cada 30s)
- `example-prometheus-metrics.js`: Código de ejemplo para instrumentar Node.js apps
- **Ver documentación completa**: [MONITORING_GUIDE.md](./MONITORING_GUIDE.md)

### Automatización
- **Init Containers**: Copian y modifican archivos HTML con URLs correctas
- **Kubernetes Job**: Ejecuta script SQL de inicialización de BD automáticamente
- **Null Resources**: 
  - Subida automática de juegos, imágenes y emulador al CDN
  - Actualización de ConfigMap con URL real del Load Balancer

## Prerrequisitos

1. **AWS CLI** configurado con credenciales
   ```bash
   aws configure
   ```

2. **Terraform** >= 1.5
   ```bash
   terraform --version
   ```

3. **kubectl** para interactuar con el cluster
   ```bash
   kubectl version --client
   ```

4. **Permisos IAM** necesarios:
   - EKS Full Access
   - VPC Full Access
   - RDS Full Access
   - EC2 Full Access
   - IAM (para roles de servicio)

## 🚀 Cómo Desplegar

### 1. Configurar Variables

**Opción A - Variables de entorno (recomendado):**

```bash
export TF_VAR_db_password="tu-password-seguro-aqui"
export TF_VAR_jwt_secret="tu-jwt-secret-largo-aqui"
```

**Opción B - Archivo terraform.tfvars:**

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Editar:
```hcl
db_password = "tu-password-seguro"
jwt_secret  = "tu-jwt-secret"
aws_region  = "eu-west-1"  # Irlanda
cluster_name = "retrogame"
```

### 2. Inicializar Terraform

```bash
cd infraestructure/terraform/eks_test
terraform init
```

**Qué hace:**
- Descarga providers (AWS, Kubernetes, Helm)
- Configura backend local para state
- Valida sintaxis de archivos .tf

### 3. Planificar el Despliegue

```bash
terraform plan
```

**Verás:**
- ~97 recursos a crear
- VPC, subnets, security groups
- EKS cluster + node group
- RDS PostgreSQL
- S3 + CloudFront
- Todos los recursos de Kubernetes

⏱️ **Tiempo de lectura**: ~30 segundos

### 4. Aplicar la Infraestructura

```bash
terraform apply
```

⏱️ **Tiempo estimado:** 15-20 minutos (incluye aprovisionamiento de nodos EC2)

El proceso creará:
- VPC con subnets públicas y privadas
- EKS Cluster con Node Groups EC2 (3x t3.micro)
- RDS PostgreSQL (db.t3.micro)
- S3 + CloudFront CDN
- Load Balancer para Kong
- Todos los recursos de Kubernetes

**Progreso:**
- 0-3 min: VPC, subnets, security groups ✅
- 3-12 min: EKS Cluster creación ⏳
- 12-15 min: Node Group (espera nodos Ready) ⏳
- 15-18 min: RDS PostgreSQL creación ⏳
- 18-19 min: CloudFront distribution ⏳
- 19-20 min: Kubernetes resources, upload assets, db-init ✅

**Qué se crea:**
```
✅ VPC con 6 subnets (3 públicas + 3 privadas)
✅ Internet Gateway + NAT Gateway
✅ EKS Cluster (Kubernetes 1.32)
✅ 3x EC2 Nodes (t3.micro) en Node Group
✅ RDS PostgreSQL 15 (db.t3.micro)
✅ S3 Bucket + CloudFront Distribution
✅ Network Load Balancer para Kong
✅ Backend, Frontend, Kong deployments
✅ DB initialization (6 tablas + 10 juegos + 1 usuario)
✅ 79 archivos subidos al CDN
```

### 5. Configurar kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name retrogame
```

**Verificar:**

```bash
kubectl get nodes  # Mostrará 3 nodos EC2 (ip-10-0-x-x.eu-west-1.compute.internal)
kubectl get pods -n retrogame
# Output:
# backend-xxxxxxxxx-xxxxx     1/1  Running    0  5m
# frontend-xxxxxxxxx-xxxxx    1/1  Running    0  5m
# kong-xxxxxxxxx-xxxxx        1/1  Running    0  5m
# db-init-xxxxx               0/1  Completed  0  5m

# Ver servicios
kubectl get svc -n retrogame
```

### 6. Obtener URLs de Acceso

```bash
terraform output
```

**Outputs importantes:**

```bash
# URL de la aplicación (Kong LoadBalancer)
kong_load_balancer_url = "http://aXXXXXXXX.elb.eu-west-1.amazonaws.com"

# URL del CDN (juegos y assets)
cdn_url = "https://dXXXXXXXXXXXX.cloudfront.net"

# Endpoint de base de datos
rds_endpoint = "retrogame-postgres.XXXXX.eu-west-1.rds.amazonaws.com:5432"

# Comando para configurar kubectl
kubectl_config = "aws eks update-kubeconfig --region eu-west-1 --name retrogame"
```

### 7. Acceder a la Aplicación

**Frontend:**
```
http://<KONG_LOAD_BALANCER_URL>
```

**Backend API:**
```bash
# Health check
curl http://<KONG_LOAD_BALANCER_URL>/api/health

# Listar juegos
curl http://<KONG_LOAD_BALANCER_URL>/api/games

# Registrar usuario
curl -X POST http://<KONG_LOAD_BALANCER_URL>/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"player1","email":"player1@test.com","password":"Test123!"}'
```

**Juegos en CDN:**
```
https://<CDN_URL>/juegos/doom.jsdos
https://<CDN_URL>/img/doom.png
https://<CDN_URL>/jsdos/js-dos.js
```

### 8. Verificar Upload de Assets

El null_resource ya subió todo automáticamente, pero puedes verificar:

```bash
# Listar archivos en S3
aws s3 ls s3://retrogame-games-cdn/ --recursive

# Debería mostrar 79 archivos:
# - juegos/*.jsdos (10 archivos)
# - img/* (imágenes de portadas)
# - jsdos/* (emulador js-dos completo)
```

Si necesitas re-subir manualmente:

```bash
cd /mnt/c/proyecto_final
aws s3 sync ./infraestructure/cdn/juegos/ s3://retrogame-games-cdn/juegos/
aws s3 sync ./infraestructure/cdn/img/ s3://retrogame-games-cdn/img/
aws s3 sync ./frontend/jsdos/ s3://retrogame-games-cdn/jsdos/
```

Los juegos estarán disponibles en:
- `https://<CLOUDFRONT_URL>/juegos/doom.jsdos`
- `https://<CLOUDFRONT_URL>/img/doom.png`

### 8. Acceder a Grafana y Prometheus (Monitoring)

Una vez desplegado el stack de monitoring, puedes acceder a Grafana para ver dashboards:

```bash
# Port-forward Grafana a localhost:3000
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Abre en tu navegador: **http://localhost:3000**

**Credenciales por defecto:**
- Usuario: `admin`
- Contraseña: `admin123` (cambiar en producción!)

**Dashboards recomendados:**
- `Kubernetes / Compute Resources / Cluster` - Vista general del cluster
- `Kubernetes / Compute Resources / Namespace (Pods)` - Métricas por namespace
- `Node Exporter / Nodes` - Métricas de nodos EC2
- `Prometheus / Overview` - Estado de Prometheus

**Acceder a Prometheus directamente:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```
Abre: **http://localhost:9090**

**Ver más detalles**: [MONITORING_GUIDE.md](./MONITORING_GUIDE.md)

## Outputs Importantes

Después del `terraform apply`, obtendrás:

```bash
# Ver todos los outputs
terraform output

# Outputs específicos
terraform output cluster_name
terraform output cluster_endpoint
terraform output rds_endpoint
terraform output kong_load_balancer_hostname
```

## 💰 Costos Estimados

### Configuración Actual (EC2 Node Groups)

| Recurso | Especificaciones | Costo Mensual |
|---------|-----------------|---------------|
| **EKS Cluster** | Control Plane | **$73.00** |
| **EC2 Nodes** | 3x t3.micro (2 vCPU, 1GB RAM) | **~$30.00** |
| **NAT Gateway** | 1x en subnet pública | **~$45.00** |
| **RDS PostgreSQL** | db.t3.micro (2 vCPU, 1GB RAM) | **~$20.00** |
| **Load Balancer** | Network Load Balancer (NLB) | **~$16.00** |
| **CloudFront** | CDN + data transfer | **~$10.00** |
| **S3** | Storage + requests | **~$5.00** |
| **Route53** | Hosted zone + queries | **~$1.00** |
| **VPC** | Subnets, route tables | **Gratis** |
| **CloudWatch Logs** | Logs de pods | **~$5.00** |
| | | |
| **TOTAL MENSUAL** | | **~$205/mes** |
| **Costo diario** | | **~$6.80/día** |
| **Hasta 11 Dic (24 días)** | | **~$165** |

### Desglose por Componente

#### EKS - $73/mes
- Costo fijo del control plane de Kubernetes
- Incluye API server, etcd, scheduler, controllers
- **No se puede reducir** (es el costo base de EKS)

#### EC2 Nodes - $30/mes
- 3x t3.micro on-demand: $0.0104/hora × 3 × 730 horas = $22.78
- Data transfer: ~$7
- **Se puede reducir** usando Spot Instances (~70% descuento)

#### NAT Gateway - $45/mes  
- $0.045/hora × 730 horas = $32.85
- Data transfer: ~$12
- **Es caro pero necesario** para que pods en subnets privadas accedan a internet
- Alternativa: Usar subnets públicas (menos seguro)

#### RDS - $20/mes
- db.t3.micro: $0.017/hora × 730 horas = $12.41
- Storage 20GB: $0.115/GB × 20 = $2.30
- Backups automáticos: ~$3
- I/O operations: ~$2

#### Load Balancer (NLB) - $16/mes
- $0.0225/hora × 730 horas = $16.43
- **Se puede reducir** usando un solo LB compartido

#### CloudFront - $10/mes
- Data transfer out: ~$8
- Requests: ~$2
- **Muy variable** según tráfico

### 💡 Optimizaciones Posibles

#### Para Desarrollo (ahorro ~$50-70/mes):
```hcl
# 1. Usar Spot Instances para nodes (-70%)
instance_types = ["t3.micro"]
capacity_type  = "SPOT"  # $7/mes vs $30/mes

# 2. Reducir a 1 NAT Gateway (-$30/mes)
# (menos HA, pero OK para dev)

# 3. RDS: Deshabilitar Multi-AZ
multi_az = false  # Ya está así

### Entorno Dev con EC2 Node Groups (configuración actual)

| Recurso | Tipo | Costo Mensual (aprox.) |
|---------|------|------------------------|
| EKS Cluster | Control Plane | $73 |
| **EC2 Node Groups** | 3x t3.micro (1 vCPU, 1GB cada uno) | **$30** |
| NAT Gateway | 1x NAT Gateway | **$45** |
| RDS PostgreSQL | db.t3.micro | $20 |
| Load Balancer | NLB | $16 |
| EBS Volumes | 3x 20GB gp3 (nodos) | $6 |
| CloudFront + S3 | CDN | $5 |
| **Monitoring Stack** | Prometheus + Grafana (EBS) | **$10** |
| **TOTAL** | | **~$205/mes** |

#### Desglose EC2 Node Groups:
- 3x t3.micro: $10/mes cada uno = $30/mes
- NAT Gateway: $32.85/mes (730 horas) + ~$12/mes (tráfico) = ~$45/mes
- EBS: 3x 20GB gp3 @ $0.08/GB = $6/mes

#### Desglose Monitoring:
- Prometheus: 10Gi EBS gp3 = ~$0.80/mes
- AlertManager: 2Gi EBS gp3 = ~$0.16/mes
- Grafana: PVC 10Gi = ~$0.80/mes
- Node Exporter DaemonSet: ~200m CPU, 512Mi RAM (distribuido en nodos)
- **Total compute incluido en nodos EC2**
- **Nota**: Si se añade LoadBalancer para Grafana: +$16/mes (no recomendado, usar port-forward)

### Alternativas de Compute

| Opción | Costo Mensual | Pros | Contras |
|--------|---------------|------|---------|
| **EC2 (3x t3.micro)** | **$205** | Económico, control total, estable | Requiere NAT Gateway, gestión básica |
| EC2 (3x t3.small) | $235 | Más recursos (2GB RAM por nodo) | Más caro (+$30/mes) |
| EC2 (3x t4g.micro ARM) | $185 | Más económico (-$20/mes) | Requiere imágenes ARM compatibles |

**Ventajas de EC2 Node Groups:**
- ✅ **Más económico**: $205/mes total
- ✅ **Mayor control**: Acceso SSH, configuración personalizada
- ✅ **Networking optimizado**: ENIs dedicadas, latencia más baja
- ✅ **Sin cold starts**: Nodos siempre activos

1. **Destroy post-entrega**: Ejecutar `terraform destroy` después del 11 Dic para evitar costos continuos
2. **Monitorear costos**: Revisar AWS Cost Explorer diariamente
3. **Configurar billing alerts**: Alert si superas $250/mes
4. **RDS backups**: Se mantienen 7 días, considera exportar data crítica
5. **Free tier**: Algunos servicios tienen free tier los primeros 12 meses (no aplica a EKS)

### Horizontal Pod Autoscaling (HPA)

Escalar pods basado en CPU/memoria:

```bash
# Crear HPA para backend
kubectl autoscale deployment backend -n retrogame --cpu-percent=70 --min=1 --max=5

# Ver estado del HPA
kubectl get hpa -n retrogame
```

**Nota:** Los 3 nodos t3.micro tienen capacidad total de ~2.5 vCPU y ~2.5GB RAM (después de pods del sistema).

### Cluster Autoscaling (Node Groups)

Configurar autoscaling de nodos EC2:

```bash
# Actualizar min/max size del node group
aws eks update-nodegroup-config \
  --cluster-name retrogame-eks \
  --nodegroup-name retrogame-node-group \
  --scaling-config minSize=2,maxSize=6,desiredSize=3
```

### Resource Requests/Limits

Configurados para optimizar uso de t3.micro nodes:

```yaml
# Backend
requests:
  cpu: 100m      # 0.1 vCPU
  memory: 256Mi  # 256 MB
limits:
  cpu: 200m      # 0.2 vCPU
  memory: 512Mi  # 512 MB

# Frontend
requests:
  cpu: 100m     # Backend: 100m, Frontend: 50m, Kong: 100m
  memory: 256Mi # Backend: 256Mi, Frontend: 128Mi, Kong: 256Mi
limits:
  cpu: 500m
  memory: 512Mi
```

**Capacidad por nodo t3.micro:**
- CPU: 1 vCPU (~900m disponible para pods)
- RAM: 1GB (~700MB disponible para pods)

## 📊 Monitoreo y Logs

### CloudWatch Logs

RDS PostgreSQL exporta logs automáticamente a CloudWatch:
- `postgresql` - Logs de consultas SQL
- `upgrade` - Logs de actualizaciones de versión

**Ver logs en AWS Console:**
```
CloudWatch → Logs → Log groups → /aws/rds/instance/retrogame-postgres/
```

### Kubernetes Metrics

Ver métricas de recursos en tiempo real:

```bash
# Métricas de nodos EC2
kubectl top nodes

# Métricas de pods
kubectl top pods -n retrogame

# Métricas de un deployment específico
kubectl top pods -n retrogame -l app=backend
```

### Ver Logs de Pods

```bash
# Logs del backend
kubectl logs -n retrogame deployment/backend --tail=50 -f

# Logs del frontend
kubectl logs -n retrogame deployment/frontend --tail=50 -f

# Logs de Kong
kubectl logs -n retrogame deployment/kong --tail=50 -f

# Logs del init container (url-replacer)
kubectl logs -n retrogame deployment/frontend -c url-replacer

# Logs del job de inicialización de DB
kubectl logs -n retrogame job/db-init
```

### Logs de Nodos EC2

```bash
# Ver qué pods están en qué nodo
kubectl get pods -n retrogame -o wide

# Describir un nodo específico
kubectl describe node <node-name>

# Ver eventos del cluster
kubectl get events -n retrogame --sort-by='.lastTimestamp'
```

# Kong
kubectl logs -n retrogame deployment/kong --tail=50 -f

# Ver logs de nodos EC2
kubectl get pods -n retrogame -o wide
kubectl describe node <node-name>
```

## 🔧 Troubleshooting

### Pods en estado Pending

```bash
kubectl describe pod <pod-name> -n retrogame
```

Posibles causas con EC2 Node Groups:
- **Recursos insuficientes**: Nodos saturados, necesitan escalar
- **Node NotReady**: Nodo EC2 con problemas, verificar status
- **Imagen no encontrada**: DockerHub rate limit o imagen inexistente
- **Secrets/ConfigMaps faltantes**: Verificar que existan en el namespace
- **Taints/Tolerations**: Verificar si hay taints en los nodos

Verificar estado de nodos:

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes  # Ver uso de CPU/RAM
```

**Causas comunes:**
- **Backend**: Error de conexión a RDS (verificar security group)
- **Frontend**: Init container falló (verificar ConfigMap con URLs)
- **Kong**: Problemas de configuración

### RDS Connection Timeout

**Verificar Security Groups:**

```bash
# Con EC2 Node Groups, los pods usan IPs privadas
# Verificar que RDS Security Group permita conexiones desde el CIDR de subnets privadas (10.0.0.0/16)
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=retrogame-rds-sg"

# Verificar conectividad desde un pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n retrogame -- \
  psql -h <RDS_ENDPOINT> -U postgres -d retrogame
```

### Load Balancer no responde

```bash
# Verificar estado del servicio
kubectl get svc kong -n retrogame

# Verificar eventos
kubectl describe svc kong -n retrogame

# Ver targets del Load Balancer en AWS Console
# EC2 → Load Balancers → <NLB> → Target Groups
```

**El NLB puede tardar 2-3 minutos en:**
- Registrar targets (pods de Kong)
- Health checks pasen
- DNS se propague

### Node Group no escala

```bash
# Ver estado del node group
aws eks describe-nodegroup \
  --cluster-name retrogame \
  --nodegroup-name retrogame-node-group

# Ver eventos del cluster autoscaler (si está instalado)
kubectl logs -n kube-system deployment/cluster-autoscaler
```

**Causas:**
- Límite de instancias EC2 en tu región
- IAM role sin permisos para crear EC2
- Desired size = max size (no puede crecer más)

### Frontend con URLs incorrectas (PLACEHOLDER)

**Síntoma**: Frontend intenta conectar a `http://.../PLACEHOLDER_LB_URL/api/...`

**Solución:**

```bash
# 1. Verificar que ConfigMap tiene la URL real
kubectl get configmap frontend-url-replacer -n retrogame -o yaml | grep LB_URL

# 2. Si tiene PLACEHOLDER, esperar a que null_resource lo actualice
terraform apply

# 3. Forzar restart del frontend
kubectl rollout restart deployment/frontend -n retrogame

# 4. Verificar que el nuevo pod tiene la URL correcta
kubectl wait --for=condition=ready pod -l app=frontend -n retrogame --timeout=120s
kubectl logs -n retrogame deployment/frontend -c url-replacer
```

### DB Init Job falla

```bash
# Ver logs del job
kubectl logs -n retrogame job/db-init

# Ver describe para más detalles
kubectl describe job db-init -n retrogame
```

**Causas comunes:**
- RDS aún no está disponible (esperar 5-8 minutos)
- Credenciales incorrectas en secret
- Security group no permite conexión

**Reintentar job manualmente:**

```bash
# Eliminar job fallido
kubectl delete job db-init -n retrogame

# Volver a aplicar
terraform apply -target=kubernetes_job.db_init
```

### Node en NotReady

```bash
# Ver estado de nodos
kubectl get nodes

# Describir nodo problemático
kubectl describe node <node-name>
```

**Soluciones:**
- Esperar 2-3 minutos (nodo iniciando)
- Verificar límites de EC2 en AWS Console
- Terminar y recrear node (AWS EKS lo reemplaza automáticamente)

```bash
# Terminar instancia EC2 problemática
aws ec2 terminate-instances --instance-ids <instance-id>
# EKS Auto Scaling Group creará un reemplazo automáticamente
```

## 🔄 Mantenimiento

### Actualizar imágenes Docker

**Cuando se hace un cambio en el código:**

1. Build y push de nueva imagen a DockerHub:
   ```bash
   cd backend  # o frontend
   docker build -t retrogamecloud/backend:v2.0 .
   docker push retrogamecloud/backend:v2.0
   ```

2. Actualizar deployment en Kubernetes:
   ```bash
   kubectl set image deployment/backend \
     backend=retrogamecloud/backend:v2.0 \
     -n retrogame
   ```

3. Verificar rollout:
   ```bash
   kubectl rollout status deployment/backend -n retrogame
   ```

3. Con EC2 Node Groups, el pod se actualizará usando rolling update (max unavailable: 25%, max surge: 25%)

### Backup de RDS

**Configuración automática:**
- **Backups diarios**: Activados
- **Retención**: 7 días
- **Ventana**: 03:00-04:00 UTC
- **Snapshots**: Sí

**Crear snapshot manual:**

```bash
aws rds create-db-snapshot \
  --db-instance-identifier retrogame-postgres \
  --db-snapshot-identifier retrogame-manual-$(date +%Y%m%d-%H%M)
```

**Restaurar desde snapshot:**

```bash
# 1. Crear nueva instancia desde snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier retrogame-postgres-restored \
  --db-snapshot-identifier retrogame-manual-20251117-1200

# 2. Actualizar endpoint en Kubernetes secret
kubectl edit secret postgres-secret -n retrogame

# 3. Restart de pods backend
kubectl rollout restart deployment/backend -n retrogame
```

### Actualizar Kubernetes

**Actualizar versión del cluster:**

```bash
# 1. Editar en variables.tf o terraform.tfvars
cluster_version = "1.33"  # De 1.32 a 1.33

# Aplicar cambios
terraform apply

# 3. AWS actualizará el control plane (~15 min)
# 4. Luego actualizará los node groups (~10 min por node group)
```

⚠️ **Nota:** Con EC2 Node Groups:
1. Primero se actualiza el control plane de EKS
2. Luego se actualiza la versión de Kubernetes en los nodos
3. Los nodos se actualizan mediante rolling update (uno a la vez)
4. Pods se drenan y migran automáticamente

**JWT Secret:**

```bash
# 1. Generar nuevo secret
NEW_JWT=$(openssl rand -base64 32)

# 2. Actualizar en Terraform
export TF_VAR_jwt_secret="$NEW_JWT"
terraform apply

# 3. Restart de backend
kubectl rollout restart deployment/backend -n retrogame
```

**Database Password:**

```bash
# 1. Cambiar password en RDS
aws rds modify-db-instance \
  --db-instance-identifier retrogame-postgres \
  --master-user-password "NuevoPasswordSeguro123!" \
  --apply-immediately

# 2. Actualizar secret en Kubernetes
kubectl edit secret postgres-secret -n retrogame
# Cambiar 'password' (base64 encoded)

# 3. Restart de backend
kubectl rollout restart deployment/backend -n retrogame
```

### Limpiar Recursos No Utilizados

**Eliminar pods completados (jobs):**

```bash
kubectl delete job --field-selector status.successful=1 -n retrogame
```

**Limpiar imágenes Docker en nodos:**

```bash
# Los nodos EC2 tienen espacio limitado
# Si se llenan, eliminar imágenes antiguas

kubectl get nodes -o name | xargs -I {} kubectl debug {} -it --image=busybox -- \
  docker system prune -a -f
```

**Limpiar logs viejos en CloudWatch:**
- Configurar retention period en log groups (ya configurado en 7 días)

### Actualizar Assets del CDN

**Subir nuevos juegos o imágenes:**

```bash
cd /mnt/c/proyecto_final

# Subir un nuevo juego
aws s3 cp ./infraestructure/cdn/juegos/nuevojuego.jsdos \
  s3://retrogame-games-cdn/juegos/

# Subir nueva imagen
aws s3 cp ./infraestructure/cdn/img/nuevojuego.png \
  s3://retrogame-games-cdn/img/

# Invalidar caché de CloudFront (opcional, para actualizaciones inmediatas)
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/juegos/nuevojuego.jsdos" "/img/nuevojuego.png"
```

**Insertar juego en base de datos:**

```bash
# Conectar a RDS
kubectl run -it --rm psql --image=postgres:15 --restart=Never -n retrogame -- \
  psql -h $(terraform output -raw rds_endpoint | cut -d: -f1) \
       -U retrogame_user \
       -d retrogame_db

# En la sesión psql:
INSERT INTO games (name, description, image_url, game_url, genre, year, created_at)
VALUES (
  'Nuevo Juego',
  'Descripción del juego',
  'https://<CDN_URL>/img/nuevojuego.png',
  'https://<CDN_URL>/juegos/nuevojuego.jsdos',
  'Action',
  1995,
  NOW()
);
```

## 🗑️ Destruir Infraestructura

⚠️ **ADVERTENCIA:** Esto eliminará TODOS los recursos y datos permanentemente.

```bash
terraform destroy
```

Confirma escribiendo `yes`.

**Tiempo estimado**: 10-15 minutos

**Proceso:**
1. Elimina recursos de Kubernetes (pods, services, deployments)
2. Elimina Load Balancer NLB (~2 min)
3. Elimina EKS Node Group (~5 min)
4. Elimina EKS Cluster (~3 min)
5. Elimina RDS (puede tardar ~5 min)
6. Elimina NAT Gateway, Internet Gateway
7. Elimina subnets y VPC
8. Elimina S3 y CloudFront (~2 min)

**Antes de destroy en producción:**

```bash
# 1. Backup de base de datos
aws rds create-db-snapshot \
  --db-instance-identifier retrogame-postgres \
  --db-snapshot-identifier retrogame-final-backup-$(date +%Y%m%d)

# 2. Exportar datos críticos
kubectl run -it --rm export --image=postgres:15 --restart=Never -n retrogame -- \
  pg_dump -h <RDS_ENDPOINT> -U retrogame_user retrogame_db > backup.sql

# 3. Descargar assets del CDN (opcional)
aws s3 sync s3://retrogame-games-cdn/ ./cdn-backup/

# 4. Notificar al equipo
echo "⚠️ Destroying infrastructure in 5 minutes..."
sleep 300
```

### Destroy Selectivo

**Eliminar solo recursos de Kubernetes:**

```bash
terraform destroy -target=kubernetes_deployment.backend
terraform destroy -target=kubernetes_deployment.frontend
terraform destroy -target=kubernetes_deployment.kong
```

**Eliminar solo RDS (mantener todo lo demás):**

```bash
terraform destroy -target=aws_db_instance.postgres
```

**Eliminar solo EKS (mantener RDS y CDN):**

```bash
terraform destroy -target=module.eks
```

### Problemas Comunes al Destroy

**Error: Load Balancer no se elimina**

```bash
# Eliminar manualmente desde AWS Console o:
aws elbv2 delete-load-balancer --load-balancer-arn <ARN>

# Luego volver a intentar
terraform destroy
```

**Error: VPC tiene dependencias**

```bash
# Ver qué recursos dependen de la VPC
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=<VPC_ID>"

# Eliminar manualmente esos recursos primero
```

**Error: S3 bucket no vacío**

```bash
# Vaciar bucket antes de destroy
aws s3 rm s3://retrogame-games-cdn/ --recursive

# Luego volver a intentar
terraform destroy
```

## 🔐 Seguridad

### Mejores Prácticas Implementadas

✅ **Network Isolation**
- VPC dedicada con subnets públicas y privadas
- Pods en subnets privadas (sin acceso directo a Internet)
- NAT Gateway para tráfico saliente
- Security Groups con reglas restrictivas
- RDS solo accesible desde CIDR de VPC (10.0.0.0/16)

✅ **Secrets Management**
- Kubernetes Secrets para credenciales sensibles
- Variables Terraform marcadas como `sensitive = true`
- Passwords no hardcodeados en código
- JWT secrets generados aleatoriamente

✅ **Encryption**
- RDS storage encriptado por defecto
- Tráfico CloudFront con HTTPS
- EBS volumes encriptados

✅ **Instance Security**
- EC2 instances con IAM roles (no access keys)
- Security Groups: solo tráfico necesario
- SSM Session Manager para acceso (sin SSH keys)

#### 4. Configurar AWS WAF
```hcl
# Agregar Web Application Firewall
resource "aws_wafv2_web_acl" "retrogame" {
  name  = "retrogame-waf"
  scope = "REGIONAL"
  
  # Reglas de protección
  # - SQL injection
  # - XSS
  # - Rate limiting
}
```

#### 5. Implementar Imagen Scanning
```bash
# Usar ECR en lugar de DockerHub
# ECR escanea vulnerabilidades automáticamente

aws ecr create-repository --repository-name retrogame/backend
aws ecr create-repository --repository-name retrogame/frontend
```

#### 6. Configurar MFA y IAM
```hcl
# Requerir MFA para acciones sensibles
# Crear IAM users con permisos limitados
# Rotar access keys regularmente
```

#### 7. HTTPS en dominio custom
```hcl
# Configurar SSL/TLS en Load Balancer
# Ver DOMAIN_SETUP.md para detalles

resource "aws_acm_certificate" "retrogame" {
  domain_name       = "retrogamehub.games"
  validation_method = "DNS"
}
```

### Security Checklist

- [ ] Secrets en AWS Secrets Manager (no en Kubernetes Secrets)
- [ ] Network Policies habilitadas
- [ ] Pod Security Standards enforced
- [ ] HTTPS en Load Balancer con certificado ACM
- [ ] WAF configurado con reglas managed
- [ ] Imágenes Docker escaneadas (ECR o Snyk)
- [ ] IAM roles con least privilege
- [ ] MFA habilitado para usuarios IAM
- [ ] CloudTrail para auditoría de cambios AWS
- [ ] Backup y DR plan documentado
- [ ] Security groups revisados (mínimo acceso necesario)
- [ ] RDS con SSL/TLS requerido
- [ ] Logs centralizados y monitoreados
- [ ] Incident response plan definido

### Vulnerabilidades Conocidas (Aceptadas para Dev)

⚠️ **Para proyecto académico:**
1. **Secrets en Kubernetes** - Deberían estar en Secrets Manager
2. **HTTP sin HTTPS** - Dominio configurado pero sin SSL aún (pendiente FASE 2)
3. **No hay WAF** - Expuesto a ataques comunes (pendiente FASE 3)
4. **RDS en subnet privada pero con password estático** - Debería rotar
5. **No hay rate limiting** - Solo en Kong (100 req/min)
6. **Imágenes de DockerHub** - Sin scan de vulnerabilidades

✅ **Aceptable porque:**
- Es un proyecto de desarrollo/académico
- No maneja datos sensibles reales
- Se destruirá después de la presentación
- Costo de implementar todo sería prohibitivo (~$100+/mes adicionales)

## Backend State (Opcional)

Para equipos, configurar S3 backend en `provider.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "tu-bucket-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

Crear recursos previos:

```bash
aws s3 mb s3://tu-bucket-terraform-state
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

## CI/CD Integration

Ejemplo de pipeline con GitHub Actions:

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: terraform init
        
      - name: Terraform Plan
        run: terraform plan
        
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
```

## Soporte

Para problemas o preguntas:
- Revisar logs de Terraform: `terraform.log`
- Revisar logs de Kubernetes: `kubectl logs`
- Consultar documentación de AWS EKS
- Abrir issue en el repositorio

## Licencia

Este proyecto es parte de RetroGameCloud.
