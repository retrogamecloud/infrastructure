# RetroGameCloud - EKS Deployment con Terraform

Este directorio contiene la infraestructura como código (IaC) para desplegar RetroGameCloud en AWS usando Amazon EKS (Elastic Kubernetes Service).

## 🎮 ¿Qué es RetroGameCloud?

RetroGameCloud es una plataforma cloud para jugar juegos retro de DOS directamente en el navegador. Utiliza el emulador js-dos para ejecutar juegos clásicos sin instalación, con rankings globales y gestión de usuarios.

## 🏗️ Arquitectura AWS

### Componentes Principales

```
Internet
    ↓
CloudFront CDN (Assets estáticos: juegos .jsdos, imágenes, emulador js-dos)
    ↓
Kong Load Balancer (NLB) → Kong API Gateway (Kubernetes)
    ↓
┌─────────────────── EKS Cluster (Kubernetes 1.34) ───────────────────┐
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   Frontend   │  │   Backend    │  │     Kong     │             │
│  │   (Node.js)  │  │  (Node.js)   │  │  (Gateway)   │             │
│  │   Port 8081  │  │  Port 3000   │  │  Port 8000   │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│         ↓                  ↓                   ↓                    │
│  3x EC2 Nodes (t3.micro) en Subnets Privadas                       │
└──────────────────────────────────────────────────────────────────────┘
                           ↓
                   NAT Gateway (Internet)
                           ↓
                  RDS PostgreSQL 15 (db.t3.micro)

VPC: 10.0.0.0/16
├── 3 Subnets Públicas (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
└── 3 Subnets Privadas (10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24)
```

### ¿Por qué EC2 Node Groups (no Fargate)?

Después de probar ambas opciones, elegimos **EC2 Node Groups** porque:

✅ **Más estable** - No hay timeouts de 15 minutos en deploys
✅ **Más económico** - $150-180/mes vs $229/mes con Fargate
✅ **Mejor control** - Podemos ajustar instance types según necesidad
✅ **Init containers funcionan** - Sin problemas de timing
✅ **Predictible** - Recursos siempre disponibles

❌ Fargate tenía problemas:
- Timeouts frecuentes en deploys largos
- Más caro para workloads constantes
- Problemas con init containers y URL replacement

## 📦 Componentes del Proyecto

### 1. **Infraestructura AWS** (archivos Terraform)

#### `provider.tf`
Configura los providers necesarios:
- **AWS Provider**: Interactúa con servicios de AWS (EKS, VPC, RDS, S3, etc.)
- **Kubernetes Provider**: Gestiona recursos dentro del cluster EKS
- **Helm Provider**: Instala charts de Helm (futuro: Prometheus, Grafana)
- **Null Provider**: Ejecuta scripts locales (upload de assets, restart de pods)

#### `variables.tf`
Define variables configurables del proyecto:
- `aws_region`: Región de AWS (default: eu-west-1 - Irlanda)
- `cluster_name`: Nombre del cluster EKS (default: retrogame)
- `cluster_version`: Versión de Kubernetes (default: 1.34)
- `db_password`: Contraseña de PostgreSQL (sensitive)
- `jwt_secret`: Secret para tokens JWT (sensitive)
- `node_instance_type`: Tipo de instancias EC2 (default: t3.micro)

#### `eks.tf` - ⭐ EKS Cluster y Networking
**Crea:**
- **VPC** (10.0.0.0/16) con 6 subnets (3 públicas + 3 privadas) en 3 AZs
- **Internet Gateway** para acceso público
- **NAT Gateway** para que pods en subnets privadas accedan a internet
- **EKS Cluster** (Kubernetes 1.34)
- **Node Group** con 3 nodos t3.micro en subnets privadas
- **Security Groups** para controlar tráfico

**¿Por qué 3 nodos?**
- Alta disponibilidad (1 por Availability Zone)
- Si 1 nodo falla, los otros 2 continúan
- Suficiente para dev/testing

**¿Qué es un Node Group?**
- Grupo de máquinas EC2 que ejecutan tus pods de Kubernetes
- Kubernetes scheduler decide en qué nodo va cada pod
- Se pueden escalar automáticamente (actualmente fijo en 3)

#### `rds.tf` - 🗄️ Base de Datos PostgreSQL
**Crea:**
- **RDS PostgreSQL 15** (instancia db.t3.micro)
- **Subnet Group** para alta disponibilidad en 3 AZs
- **Security Group** que solo permite conexiones desde VPC
- **Credenciales** almacenadas en Kubernetes Secret

**¿Por qué RDS y no PostgreSQL en Kubernetes?**
- AWS gestiona backups automáticos (7 días de retención)
- Actualizaciones de seguridad automáticas
- Snapshots para disaster recovery
- Mejor rendimiento y estabilidad
- No se pierde data si se destruye el cluster

#### `s3-cdn.tf` - 📡 CDN para Assets Estáticos
**Crea:**
- **S3 Bucket** para juegos .jsdos, imágenes, emulador js-dos
- **CloudFront Distribution** (CDN global de AWS)
- **Null Resource** que sube automáticamente 79 archivos estáticos

**¿Qué es CloudFront?**
- Red de distribución de contenido (CDN) global
- Copia tus archivos a servidores en todo el mundo
- Los usuarios descargan desde el servidor más cercano
- Más rápido y más barato que servir desde tu backend

**Archivos que se sirven:**
- Juegos: `doom.jsdos`, `duke3d.jsdos`, `wolf.jsdos`, etc. (10 juegos)
- Imágenes: Portadas de juegos, logos
- Emulador: js-dos completo (wdosbox.js, wlibzip.js, etc.)

#### `kubernetes.tf` - ☸️ Aplicaciones en Kubernetes
**Crea:**
- **Namespace**: `retrogame` (aísla recursos del cluster)
- **Secrets**: Credenciales de DB y JWT
- **ConfigMaps**: Configuración de servicios y scripts
- **Deployments**: Backend, Frontend, Kong
- **Services**: Exponen pods internamente o externamente
- **Job**: Inicialización automática de base de datos
- **Null Resources**: Automatizaciones post-deploy

#### `outputs.tf` - 📤 Información Post-Deploy
Muestra información útil después del deploy:
- URL del Load Balancer (punto de entrada a la app)
- Endpoint de RDS
- URL de CloudFront (CDN)
- Comandos útiles

---

### 2. **Aplicaciones en Kubernetes**

#### **Backend Service** (auth-service, game-catalog-service, ranking-service, score-service, user-service)
- **Lenguaje**: Node.js + Express
- **Puerto**: 3000
- **Réplicas**: 1 (puede escalar a más)
- **Recursos**: 100m CPU, 256MB RAM (requests) / 200m CPU, 512MB RAM (limits)
- **Qué hace**: 
  - API REST para autenticación (JWT)
  - CRUD de juegos
  - Gestión de scores y rankings
  - Gestión de usuarios
  - Conecta a PostgreSQL en RDS

#### **Frontend Service**
- **Lenguaje**: Node.js (sirve HTML estático)
- **Puerto**: 8081
- **Réplicas**: 1
- **Recursos**: 50m CPU, 128MB RAM (requests) / 100m CPU, 256MB RAM (limits)
- **Qué hace**:
  - Sirve archivos HTML, CSS, JavaScript
  - **Init Container** `url-replacer`: Antes de iniciar, reemplaza placeholders en HTML con URLs reales de LoadBalancer y CDN
  - Interfaz web para jugar, ver rankings, login/register

**¿Qué es un Init Container?**
- Container que se ejecuta ANTES del container principal
- Útil para preparar configuración, copiar archivos, etc.
- En nuestro caso: reemplaza `PLACEHOLDER_LB_URL` por URL real del LoadBalancer

#### **Kong API Gateway**
- **Qué es**: Proxy reverso y API Gateway
- **Puerto**: 8000 interno, expuesto en puerto 80 externamente vía LoadBalancer
- **Réplicas**: 1
- **Recursos**: 100m CPU, 256MB RAM
- **Qué hace**:
  - Recibe todas las peticiones externas
  - Enruta a backend según la ruta (`/api/*`)
  - Rate limiting (máx 100 requests/minuto por IP)
  - Logging centralizado
  - Puede agregar autenticación, CORS, etc.

**¿Por qué Kong y no acceso directo al backend?**
- **Seguridad**: Backend no está expuesto directamente
- **Rate Limiting**: Previene abuso de API
- **Single Entry Point**: Una sola URL externa
- **Futuro**: HTTPS, OAuth, métricas, circuit breaker

#### **db-init Job**
- **Qué es**: Job de Kubernetes (tarea que se ejecuta una vez)
- **Cuándo**: Automáticamente después del deploy
- **Qué hace**:
  - Conecta a RDS PostgreSQL
  - Ejecuta script SQL que crea tablas (users, games, scores, rankings, etc.)
  - Inserta 10 juegos en la tabla `games`
  - Crea 1 usuario de prueba
  - Se marca como "Completed" cuando termina

---

### 3. **Automatizaciones**

#### **null_resource.upload_static_files**
**Qué hace**:
- Después de crear CloudFront, sube automáticamente:
  - `/infraestructure/cdn/juegos/*.jsdos` → S3
  - `/infraestructure/cdn/img/*` → S3
  - `/frontend/jsdos/*` (emulador completo) → S3
- Total: 79 archivos

**Triggers**: Se ejecuta si cambia:
- El contenido del bucket S3
- Los archivos en `cdn/juegos` o `cdn/img`

#### **kubernetes_config_map_v1_data.frontend_urls**
**Qué hace**:
- Espera a que el LoadBalancer de Kong tenga una URL asignada
- Actualiza el ConfigMap con:
  - `LB_URL`: URL real del LoadBalancer (ej: http://aXXXX.elb.eu-west-1.amazonaws.com)
  - `CDN_URL`: URL de CloudFront (ej: https://dXXXX.cloudfront.net)

**¿Por qué?**
- Al inicio del deploy, no sabemos cuál será la URL del LoadBalancer
- AWS la asigna dinámicamente
- Este ConfigMap actualiza el script que usa el init container del frontend

#### **null_resource.restart_frontend**
**Qué hace**:
- Después de actualizar el ConfigMap con URLs reales
- Ejecuta `kubectl rollout restart deployment/frontend`
- Fuerza la recreación de pods del frontend
- El nuevo pod usa el ConfigMap actualizado con URLs correctas

**¿Por qué?**
- Los pods que se crearon inicialmente tienen `PLACEHOLDER_LB_URL`
- Necesitamos recrearlos para que el init container corra de nuevo
- Ahora sí reemplaza con la URL real

---

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

Escribe `yes` para confirmar.

⏱️ **Tiempo estimado:** 15-20 minutos

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
# Ver nodos EC2
kubectl get nodes
# Output: 3 nodos t3.micro en estado Ready

# Ver pods
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

# 4. Reducir nodos a 2 en horario bajo
desired_size = 2  # -$10/mes
```

#### Para Producción (costo similar, mejor rendimiento):
```hcl
# 1. Usar Reserved Instances (-40% en nodes)
# Commit de 1 año: $18/mes vs $30/mes

# 2. Usar RDS t3.small con Multi-AZ (+$20/mes)
# Mejor para alta disponibilidad

# 3. Agregar ElastiCache Redis (+$20/mes)
# Para rankings y sesiones
```

### 📊 Comparativa con Otras Opciones

| Opción | Costo Mensual | Pros | Contras |
|--------|---------------|------|--------|
| **EKS + EC2 (actual)** | **$205** | Control total, estable | NAT Gateway caro |
| EKS + Fargate | $229 | Sin gestión de nodes | Más caro, timeouts |
| ECS + Fargate | $90 | Más barato | No es Kubernetes |
| EC2 + Docker Compose | $60 | Muy barato | Sin orquestación |
| Heroku | $150 | Más simple | Vendor lock-in |
| DigitalOcean K8s | $100 | Más barato | Menos features AWS |

### ⚠️ Recordatorios Importantes

1. **Destroy post-entrega**: Ejecutar `terraform destroy` después del 11 Dic para evitar costos continuos
2. **Monitorear costos**: Revisar AWS Cost Explorer diariamente
3. **Configurar billing alerts**: Alert si superas $250/mes
4. **RDS backups**: Se mantienen 7 días, considera exportar data crítica
5. **Free tier**: Algunos servicios tienen free tier los primeros 12 meses (no aplica a EKS)

## 📈 Escalabilidad

### EC2 Node Group Autoscaling

Actualmente configurado con nodos fijos, pero se puede habilitar autoscaling:

```bash
# Ver estado actual del node group
kubectl get nodes

# Escalar manualmente el número de nodos (via Terraform)
# Editar en eks.tf:
desired_size = 5  # De 3 a 5 nodos
```

### Horizontal Pod Autoscaling (HPA)

Escalar pods basado en métricas (CPU, memoria, custom metrics):

```bash
# Ejemplo: Escalar backend basado en CPU
kubectl autoscale deployment backend -n retrogame \
  --cpu-percent=70 \
  --min=1 \
  --max=5

# Ver estado de HPA
kubectl get hpa -n retrogame
```

### Escalado Manual de Pods

```bash
# Escalar backend
kubectl scale deployment backend -n retrogame --replicas=3

# Escalar frontend
kubectl scale deployment frontend -n retrogame --replicas=2

# Ver réplicas actuales
kubectl get deployment -n retrogame
```

**Costo por réplica adicional:**
- Backend (100m CPU, 256MB RAM): ~$10-15/mes por réplica
- Frontend (50m CPU, 128MB RAM): ~$5-8/mes por réplica

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
  cpu: 50m       # 0.05 vCPU
  memory: 128Mi  # 128 MB
limits:
  cpu: 100m      # 0.1 vCPU
  memory: 256Mi  # 256 MB
```

**Capacidad por nodo t3.micro:**
- 2 vCPU disponibles
- ~700MB RAM disponible (1GB - sistema)
- Puede ejecutar ~7-10 pods pequeños

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

# Ver logs de Fargate nodes
kubectl get pods -n retrogame -o wide
```

## 🔧 Troubleshooting

### Pods en estado Pending

```bash
kubectl describe pod <pod-name> -n retrogame
```

**Posibles causas con EC2 Node Groups:**
- **Recursos insuficientes**: Nodos t3.micro sin espacio para más pods
  - Solución: Escalar node group o reducir resource requests
- **Imagen no encontrada**: DockerHub rate limit o imagen inexistente
  - Solución: Verificar nombre de imagen en deployment
- **Secrets/ConfigMaps faltantes**: Pod esperando por recursos
  - Solución: Verificar que secrets y configmaps existen

**Verificar capacidad de nodos:**

```bash
# Ver recursos disponibles en cada nodo
kubectl describe nodes | grep -A 5 "Allocated resources"

# Ver pods por nodo
kubectl get pods -n retrogame -o wide
```

### Pods en CrashLoopBackOff

```bash
# Ver logs del container que falla
kubectl logs -n retrogame <pod-name> --previous

# Ver eventos del pod
kubectl describe pod <pod-name> -n retrogame
```

**Causas comunes:**
- **Backend**: Error de conexión a RDS (verificar security group)
- **Frontend**: Init container falló (verificar ConfigMap con URLs)
- **Kong**: Problemas de configuración

### RDS Connection Timeout

**Verificar Security Groups:**

```bash
# Obtener security group de RDS
aws rds describe-db-instances \
  --db-instance-identifier retrogame-postgres \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId'

# Verificar reglas del security group
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions'
```

**Debe permitir:**
- Port 5432 desde CIDR de VPC (10.0.0.0/16)
- O desde security group de EKS nodes

**Probar conectividad desde un pod:**

```bash
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n retrogame -- \
  psql -h <RDS_ENDPOINT> -U retrogame_user -d retrogame_db
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

4. Rollback si hay problemas:
   ```bash
   kubectl rollout undo deployment/backend -n retrogame
   ```

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

# 2. Aplicar cambios
terraform apply

# 3. AWS actualizará el control plane (~15 min)
# 4. Luego actualizará los node groups (~10 min por node group)
```

**⚠️ Importante:**
- AWS actualiza nodos de uno en uno (rolling update)
- Los pods se migran automáticamente a otros nodos
- No hay downtime si tienes múltiples réplicas

### Rotar Secrets

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
- VPC dedicada (10.0.0.0/16) aislada
- Subnets privadas para nodes (10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24)
- Subnets públicas solo para NAT Gateway y Load Balancer
- Security Groups con reglas restrictivas
- RDS solo accesible desde VPC CIDR

✅ **Secrets Management**
- Kubernetes Secrets para credenciales sensibles
- Variables Terraform marcadas como `sensitive = true`
- Passwords no hardcodeados en código
- JWT secrets generados aleatoriamente

✅ **Encryption**
- RDS storage encriptado por defecto
- Tráfico CloudFront con HTTPS
- Comunicación interna en Kubernetes encriptada

✅ **Access Control**
- EKS usa IAM roles para autenticación
- Service Accounts con RBAC
- Node groups con IAM role específico
- Principio de least privilege

✅ **Logging & Auditing**
- CloudWatch Logs para RDS
- Kubernetes events y logs
- Load Balancer access logs (opcional)

### Recomendaciones Adicionales para Producción

#### 1. Habilitar Secrets Manager
```hcl
# Migrar secrets a AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "retrogame/db/password"
}

# Usar External Secrets Operator en Kubernetes
# https://external-secrets.io/
```

#### 2. Implementar Network Policies
```yaml
# Restringir tráfico entre pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: retrogame
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: kong
    ports:
    - protocol: TCP
      port: 3000
```

#### 3. Habilitar Pod Security Standards
```yaml
# Enforced security policies
apiVersion: v1
kind: Namespace
metadata:
  name: retrogame
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

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
