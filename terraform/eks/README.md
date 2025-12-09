# RetroGameCloud - EKS Deployment con Terraform

Este directorio contiene la infraestructura como código (IaC) para desplegar RetroGameCloud en AWS usando Amazon EKS (Elastic Kubernetes Service).

## Descripción

Solución completa de infraestructura en Kubernetes con:
- **EKS Cluster** (Kubernetes 1.34) con EC2 Node Groups (t3.small, 4 nodos)
- **ALB + NGINX Ingress** para routing de tráfico
- **ArgoCD** para GitOps deployment automático
- **Monitoring Stack** (Prometheus + Grafana + AlertManager) con GitHub OAuth
- **RDS PostgreSQL 15** para persistencia de datos
- **S3 + CloudFront** para CDN de assets estáticos

La arquitectura utiliza **módulos Terraform** certificados de AWS para máxima calidad y mantenibilidad.

## Tabla de contenidos

- [Descripción](#descripción)
- [Arquitectura](#arquitectura)
- [Estructura de archivos](#estructura-de-archivos)
- [Archivos .tf Principales](#archivos-tf-principales)
- [Prerequisitos](#prerequisitos)
- [Guía de despliegue](#guía-de-despliegue)
- [Configuración](#configuración)
- [Escalabilidad y Operaciones](#escalabilidad-y-operaciones)
- [Monitoreo y Troubleshooting](#monitoreo-y-troubleshooting)
- [Mantenimiento](#mantenimiento)
- [Destruir Infraestructura](#destruir-infraestructura)
- [Seguridad](#seguridad)

## Arquitectura

### Componentes principales

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                 Internet                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                     Application Load Balancer (ALB)                     │
│  HTTP:80 → HTTPS:443 (ACM Certificate)                                  │
│  Path-based routing:                                                    │
│  / → Frontend (público)                                                 │
│  /oauth2/* → OAuth2-Proxy (GitHub auth)                                 │
│  /wiki/* → Wiki/Mintlify (proxy externo)                                │
│  /grafana/* → Grafana (protegido)                                       │
│  /prometheus/* → Prometheus (protegido)                                 │
│  /argocd* → ArgoCD v3.2.0 (protegido)                                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                   NGINX Ingress Controller (ClusterIP)                  │
│  Gestiona ingress rules internas                                        │
│  TLS termination (Let's Encrypt)                                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌───────────────────── EKS Cluster (Kubernetes 1.34) ─────────────────────┐
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Namespaces:                                                       │  │
│  │                                                                   │  │
│  │ retrogame       | kube-system | monitoring       | argocd         │  │
│  │ ├─ Frontend     | ├─ CoreDNS  | ├─ Prometheus    | ├─ ArgoCD      │  │ 
│  │ ├─ Backend      | └─ VPC-CNI  | ├─ Grafana       | └─ Repo Server │  │
│  │ └─ Job DB-Init  |             | ├─ AlertManager  |                │  │
│  │                 |             | └─ oauth2-proxy  |                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  EC2 Node Group: 4 nodos t3.small (2 vCPU, 2GB RAM cada uno)            │
│  ├─ Subnets privadas (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)            │
│  ├─ Auto Scaling: min=2, desired=4, max=6                               │
│  ├─ Cluster Autoscaler habilitado                                       │
│  └─ Metrics Server para HPA                                             │
│                                                                         │
│  Add-ons de EKS:                                                        │
│  ├─ CoreDNS (servicio DNS interno)                                      │
│  ├─ kube-proxy (networking)                                             │
│  └─ VPC-CNI (IP management)                                             │
│                                                                         │
│  Helm Releases:                                                         │
│  ├─ NGINX Ingress Controller                                            │
│  ├─ Kube Prometheus Stack (Prometheus + Grafana + AlertManager)         │
│  ├─ Cluster Autoscaler                                                  │
│  ├─ AWS Load Balancer Controller                                        │
│  ├─ oauth2-proxy (GitHub authentication)                                │
│  └─ ArgoCD v3.2.0 (Chart v5.51.6) - GitOps                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS Services Externos                          │
│                                                                         │
│  ├─ RDS PostgreSQL 15 (db.t3.micro)                                     │
│  │  ├─ Storage: 20GB gp3 encriptado                                     │
│  │  ├─ Backup: 1-7 días según entorno                                   │
│  │  └─ Multi-AZ: No (dev) / Sí (prod)                                   │
│  │                                                                      │
│  ├─ S3 Buckets                                                          │
│  │  ├─ Games CDN: juegos .jsdos + imágenes + emulador                   │
│  │  └─ CDN Logs: logs de acceso                                         │
│  │                                                                      │
│  ├─ CloudFront Distribution (CDN)                                       │
│  │  ├─ Origin: S3 bucket                                                │
│  │  └─ Distribution: Cache global                                       │
│  │                                                                      │
│  ├─ VPC (10.0.0.0/16)                                                   │
│  │  ├─ 3 Subnets públicas (10.0.101-103.0/24)                           │
│  │  ├─ 3 Subnets privadas (10.0.1-3.0/24)                               │ 
│  │  ├─ NAT Gateway (1 en subnet pública)                                │
│  │  └─ Internet Gateway                                                 │
│  │                                                                      │
│  └─ Security Groups                                                     │
│     ├─ ALB: 80/443 desde internet                                       │
│     ├─ Nodes: tráfico interno + egress                                  │
│     └─ RDS: 5432 desde VPC CIDR                                         │
└─────────────────────────────────────────────────────────────────────────┘

S3 + CloudFront
     ↓
/juegos/doom.jsdos
/img/doom.png
/jsdos/js-dos.js
```

## Estructura de archivos

```
eks/
├── provider.tf              # Providers AWS, Kubernetes, Helm, Null, Random
├── variables.tf             # Variables de entrada (región, cluster_version, DB, etc.)
├── data.tf                  # Data sources (account ID, availability zones, etc.)
├── backend.conf             # Backend S3 config (from bootstrap project)
├── 
├── eks.tf                   # VPC + EKS Cluster + Node Group (terraform-aws-modules)
├── kubernetes.tf            # Namespaces, Secrets, ConfigMaps (desde Terraform)
├── rds.tf                   # PostgreSQL 15 (db.t3.micro)
├── s3-cdn.tf                # S3 buckets + CloudFront distribution
├── 
├── ingress_nginx.tf         # NGINX Ingress Controller (Helm)
├── alb.tf                   # Application Load Balancer (ALB)
├── oauth2_proxy.tf          # oauth2-proxy para GitHub authentication
├── 
├── argocd.tf                # ArgoCD (Helm) - GitOps deployment
├── monitoring.tf            # Prometheus Stack (Helm) - kube-prometheus-stack
├── ebs-csi-driver.tf        # EBS CSI Driver (storage)
├── ingress_monitoring.tf    # Ingress para Grafana, Prometheus, AlertManager
├── 
├── route53.tf               # DNS records (opcional)
├── 
├── outputs.tf               # Outputs importantes (URLs, endpoints)
├── README.md                # Este archivo
│
├── values/
│   ├── argocd-values.yaml   # Helm values customizados para ArgoCD
│   └── ...
│
└── .gitignore
    ├── terraform.tfstate*   # NO commitear estado local
    ├── .terraform/
    └── *.tfvars
```

## Archivos .tf principales

### provider.tf
- **AWS Provider** (v5.0): Gestiona recursos AWS
- **Kubernetes Provider** (v2.23): CRUD de recursos K8s (deployments, services, ingress)
- **Helm Provider** (v2.11): Instala/actualiza charts (NGINX, Prometheus, ArgoCD)
- **Null Provider** (v3.2): Ejecuta provisioners y scripts locales
- **Random Provider** (v3.5): Genera valores aleatorios (cookies secrets)
- **Backend S3**: Estado remoto en bucket creado por bootstrap project
  - Bucket: `retrogamecloud-terraform-state-<ACCOUNT_ID>`
  - DynamoDB: `terraform-lock` (para concurrencia)

### variables.tf
Configuración parametrizable:
| Variable | Defecto | Ejemplo Alternativo | Tipo | Sensible |
|----------|---------|-------------------|------|----------|
| `aws_region` | eu-west-1 | us-east-1, ap-southeast-1 | string | No |
| `aws_profile` | retrogamecloud-terraform | default, prod-profile | string | No |
| `cluster_name` | retrogame | retrogame-prod, gaming-k8s | string | No |
| `cluster_version` | 1.34 | 1.33, 1.35 | string | No |
| `vpc_cidr` | 10.0.0.0/16 | 10.1.0.0/16, 172.16.0.0/16 | string | No |
| `node_instance_types` | ["t3.small"] | ["t3.medium"], ["t3.small", "t3.micro"] | list(string) | No |
| `node_desired_size` | 4 | 2 (dev), 8 (prod) | number | No |
| `node_min_size` | 2 | 1 (dev), 3 (prod) | number | No |
| `node_max_size` | 6 | 4 (dev), 12 (prod) | number | No |
| `db_instance_class` | db.t3.micro | db.t3.small, db.t3.medium | string | No |
| `db_allocated_storage` | 20 | 50 (prod), 100 (prod-high) | number | No |
| `db_password` | - | (generated: openssl rand -b64 32) | string | **Sí** |
| `jwt_secret` | - | (generated: openssl rand -b64 32) | string | **Sí** |
| `github_oauth_client_id` | - | (from GitHub App settings) | string | **Sí** |
| `github_oauth_client_secret` | - | (from GitHub App settings) | string | **Sí** |
| `slack_webhook_url` | (default) | https://hooks.slack.com/... | string | **Sí** |

### eks.tf
**Módulos Terraform certificados:**
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  # Crea: VPC, subnets (3 pub + 3 priv), NAT Gateway, Internet Gateway
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  # Crea: EKS Cluster, Node Group (4 nodos t3.small)
  # Add-ons: CoreDNS, kube-proxy, VPC-CNI
}
```

**Recursos creados:**
- **VPC**: 10.0.0.0/16
  - 3 Subnets públicas: 10.0.101-103.0/24 (ALB, NAT Gateway)
  - 3 Subnets privadas: 10.0.1-3.0/24 (EKS nodes)
  - NAT Gateway: Permite egress de pods en subnets privadas
  - Internet Gateway: Acceso desde internet al ALB
- **EKS Cluster**: Kubernetes 1.34
  - Control plane en AWS managed
  - Endpoint público para kubectl
- **Node Group**:
  - Nombre: `general-nodes`
  - Instance type: t3.small (2 vCPU, 2GB RAM)
  - Desired: 4 nodos
  - Autoscaling: min=2, max=6
  - Estrategia: ON_DEMAND (no Spot)
  - AMI: AL2023_x86_64_STANDARD (Amazon Linux 2023)
- **Addons EKS**:
  - CoreDNS: DNS del cluster
  - kube-proxy: Networking
  - VPC-CNI: IP management (pods usan IPs de VPC)

**Add-ons adicionales instalados vía Helm:**
- **Cluster Autoscaler**: Scale automático de nodos
- **Metrics Server**: Métricas para HPA (Horizontal Pod Autoscaling)
- **AWS Load Balancer Controller**: Crea ALB/NLB automáticamente

### kubernetes.tf
Recursos K8s creados vía Terraform:
- **Namespace `retrogame`**: Aisla aplicaciones
- **Secrets**:
  - `jwt-secret`: JWT_SECRET para autenticación
  - `postgres-credentials`: Conexión a RDS
- **ConfigMaps**: Configuración de aplicaciones

**Nota**: Backend y Frontend deployments comentados porque **ArgoCD** ahora los gestiona.

### rds.tf
**PostgreSQL 15** gestionado:
```
Identifier:     retrogame-postgres
Instance class: db.t3.micro (2 vCPU, 1GB RAM)
Storage:        20GB gp3 (SSD)
Engine version: 15.15
Backup:         1 día (dev) / 7 días (prod)
Multi-AZ:       No (dev) / Sí (prod)
Subnet group:   Privadas (10.0.1-3.0/24)
Security group: 5432 desde VPC CIDR (10.0.0.0/16)
```

**Credenciales:**
- Usuario: `retrogame` (variable `db_username`)
- Password: Desde variable `db_password` (sensible)
- DB name: `retrogamedb`

### s3-cdn.tf
**2 S3 Buckets:**
1. **`retrogame-games-cdn`** (principal)
   - Contenido: juegos .jsdos + imágenes + emulador js-dos
   - Versionado: Habilitado
   - Acceso público: Bloqueado (usa CloudFront)
   - Política: Solo HTTPS
   - Logging: Enviados a segundo bucket

2. **`retrogame-cdn-logs`** (logs)
   - Contenido: Logs de acceso del primer bucket
   - ACL: log-delivery-write

**CloudFront Distribution:**
- Origin: S3 bucket (con OAI - Origin Access Identity)
- Cache: 86400s (1 día) para assets estáticos
- Compression: Habilitada para texto
- Distribution domain: `d<XXXX>.cloudfront.net`

### ingress_nginx.tf
**NGINX Ingress Controller** v4.11.3:
- Service type: ClusterIP (ALB hace el trabajo de LB)
- Port: 80 dentro del cluster
- Config:
  - `use-forwarded-headers: true` (confiar en headers del ALB)
  - `proxy-body-size: 50m` (permitir uploads grandes)
  - `ssl-redirect: false` (ALB termina HTTPS)
- Metrics: Habilitadas para Prometheus

### alb.tf
**Application Load Balancer** con HTTPS:
- Listener puerto 80 → redirect a 443
- Listener puerto 443 → target group de NGINX
- Certificado: ACM (Let's Encrypt)
- Dominio: retrogamehub.games (via Route53)
- Path-based routing:
  ```
  /                 → frontend
  /oauth2/*         → oauth2-proxy
  /wiki/*           → Wiki/Mintlify (proxy externo)
  /grafana/*        → Grafana (protegido)
  /prometheus/*     → Prometheus (protegido)
  /argocd*          → ArgoCD (protegido)
  ```

### oauth2_proxy.tf
**OAuth2-Proxy** para autenticación:
- Proveedor: GitHub
- Secreto de cookies: Generado aleatoriamente
- Autenticación:
  - GitHub OAuth App credentials (desde variables)
  - Restricción: Organización `retrogamecloud`
  - Roles: automático desde membership de GitHub
- ConfigMap: Configuración de oauth2_proxy.cfg
- Deployment: 1 réplica
- Service: ClusterIP (accesible desde NGINX)

### kubernetes.tf (Wiki)
**Wiki/Mintlify** (Documentación externa):
- Tipo: ExternalName Service (proxy a documentación externa)
- Path: `/wiki/*` con regex rewrite: `/wiki(/|$)(.*)`
- Origen: Servicio externo de documentación (Mintlify)
- Ingress: Enrutada desde NGINX
- Función:
  - Servir documentación técnica
  - Accesible públicamente sin autenticación
  - Assets estáticos con rewrite de URLs
- Ingress adicional para assets estáticos: `/wiki-assets/*`

### argocd.tf
**ArgoCD v3.2.0** (Chart Helm v5.51.6) - GitOps:
- Chart: `argo-cd` v5.51.6 desde repo oficial
- Imagen: ArgoCD v3.2.0 (especificada en `global.image.tag`)
- Namespace: `argocd` (separado)
- Values: `argocd-values.yaml` customizado
- Ingress: Detrás de oauth2-proxy (GitHub auth)
- Función:
  - Sincronizar aplicaciones desde git repos
  - Automatizar deployments
  - Revertir cambios fácilmente
  
**Acceso:**
- URL: `https://retrogamehub.games/argocd`
- Auth: GitHub OAuth
- Admin password: Guardado en secret

### monitoring.tf
**Kube Prometheus Stack** (Prometheus Operator):
- Componentes:
  - Prometheus: Recolecta métricas (3d retención)
  - Grafana: Dashboards + visualización
  - AlertManager: Manejo de alertas
  - Node Exporter: Métricas de nodos EC2
  - Kube State Metrics: Estado de K8s objects
  - Prometheus Operator: Gestiona PrometheusRules

- Secrets:
  - Slack webhook para AlertManager

- ConfigMaps:
  - Configuración de Prometheus
  - Grafana dashboards

- Persistencia:
  - PVC para Prometheus (10GB)
  - Grafana: ephemeral (configuración vía ConfigMap)

### oauth2_proxy + argocd + monitoring
Estos componentes trabajan juntos:
1. **ALB** recibe petición a `/argocd` o `/grafana`
2. **oauth2-proxy** intercepta y redirige a GitHub si no autenticado
3. GitHub auth → vuelve con token válido
4. **NGINX Ingress** enruta al servicio correspondiente
5. **ArgoCD** / **Grafana** / **Prometheus** accesibles

---

## Prerequisitos

### Herramientas Requeridas
- **Terraform** >= 1.13
  ```bash
  terraform --version
  # Terraform v1.13 o superior
  ```

- **AWS CLI** >= v2 configurada
  ```bash
  aws --version
  aws configure --profile retrogamecloud-terraform
  # Credenciales con permisos de administrador
  ```

- **kubectl** para interactuar con cluster
  ```bash
  kubectl version --client
  # Version 1.27+
  ```

- **Helm** para gestionar charts
  ```bash
  helm version
  # v3.12+
  ```

### ⚠️ Proyecto Bootstrap (OBLIGATORIO - Ejecutar Primero)

**IMPORTANTE:** Este proyecto depende completamente de `infrastructure/terraform/bootstrap`. **DEBES ejecutar bootstrap ANTES de este proyecto EKS.**

Bootstrap crea:
- ✅ S3 bucket para estado remoto de Terraform
- ✅ DynamoDB table para locks (evita ejecuciones concurrentes)
- ✅ Usuarios IAM requeridos
- ✅ Políticas de acceso a S3

**Pasos previos obligatorios:**
```bash
# 1. Navegar al directorio bootstrap
cd infrastructure/terraform/bootstrap

# 2. Ejecutar bootstrap (completamente)
terraform init
terraform apply

# 3. Verificar que se creó correctamente
terraform output terraform_state_bucket -json
# Output esperado: "retrogamecloud-terraform-state-123456789012"

# 4. SOLO DESPUÉS, volver a eks
cd ../eks
```

**Sin ejecutar bootstrap primero, este proyecto fallará.**

### Credenciales sensibles requeridas
Necesitarás generar:

1. **GitHub OAuth App** (para oauth2-proxy)
   - Ir a: https://github.com/settings/developers
   - New OAuth App
   - Homepage URL: `https://retrogamehub.games`
   - Authorization callback: `https://retrogamehub.games/oauth2/callback`
   - Copiar Client ID y Client Secret

2. **Slack Webhook** (para alertas de AlertManager)
   - Opcional pero recomendado
   - Ir a: https://api.slack.com/apps
   - Create New App → From scratch
   - Habilitar Incoming Webhooks
   - Copiar Webhook URL

### Permisos IAM Mínimos
El usuario/role de AWS necesita permisos para:
- EKS (creación de clusters, node groups, addons)
- EC2 (crear instances, security groups, AMI)
- VPC (subnets, route tables, nat gateways, internet gateways)
- RDS (crear instancias, snapshots)
- S3 (crear buckets, objetos)
- CloudFront (distribuciones)
- ALB (load balancers, target groups)
- ACM (certificados SSL)
- Route53 (DNS records)
- IAM (roles, policies, users)
- CloudWatch (logs, alarms)

**Recomendado:** Usar `AdministratorAccess` policy

## Guía de despliegue

### Paso 0: Ejecutar Bootstrap (OBLIGATORIO)

**Antes de comenzar, DEBES ejecutar el proyecto bootstrap:**

```bash
# Ir al directorio bootstrap
cd infrastructure/terraform/bootstrap

# Inicializar y aplicar
terraform init
terraform apply

# Esperar a que termine completamente (~5-10 min)

# Verificar que se creó el bucket S3
terraform output terraform_state_bucket
# Output esperado: retrogamecloud-terraform-state-<ACCOUNT_ID>

# SOLO DESPUÉS DE ESTO, volver a eks
cd ../eks
```

**⚠️ Si no ejecutas bootstrap primero, los siguientes pasos fallarán.**

### Paso 1: Clonar repositorio y preparar variables

```bash
cd infrastructure/terraform/eks

# Crear archivo de variables
cat > terraform.tfvars <<EOF
# AWS Configuration
aws_region  = "eu-west-1"
aws_profile = "retrogamecloud-terraform"

# Cluster Configuration  
cluster_name    = "retrogame"
cluster_version = "1.34"
environment     = "dev"

# Node Group Configuration
node_instance_types = ["t3.small"]
node_desired_size   = 4
node_min_size       = 2
node_max_size       = 6

# Database Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20
db_password = "TuPassword123!Seguro" # CAMBIA ESTO

# Application Secrets
jwt_secret = "$(openssl rand -base64 32)"

# GitHub OAuth (del paso anterior)
github_oauth_client_id     = "Tu_Client_ID_Aqui"
github_oauth_client_secret = "Tu_Client_Secret_Aqui"

# Slack Webhook (opcional)
slack_webhook_url = "https://hooks.slack.com/services/T.../B.../..."

# Tags adicionales
tags = {
  Cost-Center = "Tech"
  Owner       = "DevOps"
}
EOF
```

### Paso 2: Inicializar Terraform (con backend remoto)

```bash
# Inicializar con backend remoto del proyecto bootstrap
# backend.conf referencia automáticamente el bucket creado en bootstrap
terraform init -backend-config=backend.conf

# Verificar que está usando backend S3
terraform show | grep backend
# Debería mostrar referencia al bucket S3 de bootstrap
```

**¿Qué hace `backend.conf`?**
```hcl
bucket       = "retrogamecloud-terraform-state-<ACCOUNT_ID>"
key          = "eks/terraform.tfstate"
region       = "eu-west-1"
dynamodb_table = "terraform-lock"
```

### Paso 3: Validar configuración

```bash
terraform validate
# Output: Success! The configuration is valid.

# Revisar archivos de variables
terraform plan -var-file=terraform.tfvars | head -50
# Muestra primeros 50 recursos a crear
```

### Paso 4: Planificar despliegue

```bash
terraform plan -out=tfplan

# Output espera: ~150-200 recursos a crear
# Tiempo: ~30-60 segundos

# Revisar el plan en detalle
terraform show tfplan | grep "Resource actions"
```

**Principales recursos a crear:**
```
+ aws_vpc.main
+ aws_subnet.private (x3) + aws_subnet.public (x3)
+ aws_nat_gateway (x1) + aws_internet_gateway (x1)
+ aws_eks_cluster.main
+ aws_eks_node_group.general (4 nodos t3.small)
+ aws_db_instance.postgres
+ aws_s3_bucket.games_cdn + aws_cloudfront_distribution
+ aws_lb.main (ALB)
+ kubernetes_namespace.retrogame
+ kubernetes_secret (jwt-secret, postgres-credentials)
+ helm_release.ingress_nginx
+ helm_release.kube_prometheus_stack
+ helm_release.argocd
+ kubernetes_deployment.oauth2_proxy
+ etc...
```

### Paso 5: Aplicar cambios

```bash
terraform apply tfplan

# Confirmará recursos a crear. Escribir "yes"
# TIEMPO ESTIMADO: 20-35 minutos
```

**Progreso esperado:**
```
✓ VPC, subnets, internet/NAT gateways        [~2 min]
✓ EKS Control Plane                           [~8 min]  ⏳ Lo más lento
✓ Node Group (4 nodos t3.small)               [~8 min]  ⏳
✓ RDS PostgreSQL 15                           [~8 min]
✓ S3 Buckets + CloudFront                     [~2 min]
✓ ALB + Target Groups                         [~2 min]
✓ NGINX Ingress Controller (Helm)             [~1 min]
✓ Monitoring Stack (Helm)                     [~2 min]
✓ ArgoCD (Helm)                               [~1 min]
✓ oauth2-proxy + configuración                [~1 min]
```

**Durante la creación:**
```bash
# En otra terminal, monitorear el cluster (después de 8 min)
aws eks update-kubeconfig --name retrogame --region eu-west-1 --profile retrogamecloud-terraform
kubectl get nodes -w
# Esperar a que los 4 nodos estén en Ready
```

### Paso 6: Verificar despliegue

```bash
# Obtener información de salida
terraform output

# Información crítica:
terraform output -raw alb_dns_name
terraform output -raw rds_endpoint
terraform output -raw cdn_distribution_domain

# Configurar kubectl automáticamente
aws eks update-kubeconfig --name retrogame --region eu-west-1 --profile retrogamecloud-terraform

# Verificar nodos
kubectl get nodes
# Output:
# NAME                          STATUS   ROLES    AGE   VERSION
# ip-10-0-1-xx.ec2.internal    Ready    <none>   3m    v1.34.x
# ip-10-0-2-xx.ec2.internal    Ready    <none>   3m    v1.34.x
# ip-10-0-3-xx.ec2.internal    Ready    <none>   3m    v1.34.x
# ip-10-0-1-yy.ec2.internal    Ready    <none>   3m    v1.34.x

# Verificar pods en todos los namespaces
kubectl get pods -A
# Output: Pods de ingress-nginx, monitoring, argocd, etc.

# Verificar servicios
kubectl get svc -A
# Output: ALB, Services de nginx-ingress, prometheus, grafana, etc.
```

### Paso 7: Acceder a la aplicación

**Frontend:**
```
https://retrogamehub.games/
```

**Servicios protegidos con GitHub OAuth:**
```
https://retrogamehub.games/argocd      (ArgoCD)
https://retrogamehub.games/grafana     (Grafana Dashboards)
https://retrogamehub.games/prometheus  (Prometheus Queries)
https://retrogamehub.games/alertmanager (Alert Manager)
```

**Acceso ArgoCD:**
```bash
# Obtener contraseña de admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Username: admin
# Password: (output del comando anterior)
```

**Acceso Grafana:**
```bash
# Obtener contraseña de admin
kubectl -n monitoring get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Username: admin
# Password: (output del comando anterior)
```

### Paso 8: Verificar componentes clave

```bash
# 1. NGINX Ingress Controller
kubectl get svc -n ingress-nginx
# Debería mostrar ingress-nginx-controller (ClusterIP)

# 2. Monitoring Stack
kubectl get pods -n monitoring | grep -E "prometheus|grafana|alertmanager"
# Deberían estar Running

# 3. ArgoCD
kubectl get pods -n argocd
# Deberían estar Running

# 4. oauth2-proxy
kubectl get deployment oauth2-proxy -n monitoring
# Debería estar Running

# 5. Ingress Rules
kubectl get ingress -A
# Deberían mostrar ingress para argocd, ingress_monitoring, etc.

# 6. Base de datos
kubectl get pvc -n retrogame
# Debería mostrar postgres-data si está usando storage persistente

# 7. Secretos
kubectl get secrets -n monitoring
# Deberían mostrar oauth2-proxy, alertmanager-slack-webhook, etc.
```

## Configuración

### Variables Principales (terraform.tfvars)

```hcl
# AWS Configuration
aws_region  = "eu-west-1"
aws_profile = "retrogamecloud-terraform"

# Cluster Configuration
cluster_name    = "retrogame"
cluster_version = "1.34"
environment     = "dev"
environment_prefix = "dev"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
azs      = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# Node Group Configuration
node_instance_types = ["t3.small"]
node_desired_size   = 4
node_min_size       = 2
node_max_size       = 6
node_disk_size      = 30

# Database Configuration
db_instance_class      = "db.t3.micro"
db_allocated_storage   = 20
db_engine_version      = "15"
db_backup_retention    = 7       # 7 días en prod, 1 día en dev
db_multi_az           = false    # true en producción
db_storage_encrypted  = true
db_password           = "TuPassword123!Seguro"

# Application Secrets
jwt_secret = "$(openssl rand -base64 32)"

# GitHub OAuth Configuration
github_oauth_client_id     = "Tu_Client_ID_Aqui"
github_oauth_client_secret = "Tu_Client_Secret_Aqui"

# Slack Webhook (opcional pero recomendado)
slack_webhook_url = "https://hooks.slack.com/services/T.../B.../..."

# Dominio
domain_name = "retrogamehub.games"

# Tags
tags = {
  Environment = "Development"
  Project     = "RetroGameCloud"
  ManagedBy   = "Terraform"
  Cost-Center = "Tech"
}
```

### Backend Configuration (backend.conf)

```hcl
# Este archivo debe coincidir con el bucket creado en bootstrap
bucket       = "retrogamecloud-terraform-state-<ACCOUNT_ID>"
key          = "eks/terraform.tfstate"
region       = "eu-west-1"
encrypt      = true
dynamodb_table = "terraform-lock"
```

**Cómo obtener ACCOUNT_ID:**
```bash
aws sts get-caller-identity --profile retrogamecloud-terraform

# Output:
# {
#     "UserId": "AIDAI...",
#     "Account": "450545962171",
#     "Arn": "arn:aws:iam::450545962171:user/retrogamecloud-terraform"
# }

# El valor "Account" es tu ACCOUNT_ID
```

### Archivos Terraform Clave

#### 1. variables.tf
Define 17 variables con valores por defecto (ver tabla anterior)

#### 2. provider.tf
Configura 5 proveedores:
- **aws** (~5.0): VPC, EKS, RDS, S3, CloudFront, ALB
- **kubernetes** (~2.23): Namespaces, Secrets, ConfigMaps, Ingress
- **helm** (~2.11): Charts (NGINX, Monitoring, ArgoCD)
- **null** (~3.2): Recursos locales (kubeconfig updates)
- **random** (~3.5): Secrets aleatorios

Backend S3 desde bootstrap project

#### 3. Archivos de Configuración Helm

**values/argocd-values.yaml** - ArgoCD con OAuth2-proxy
**values/monitoring-values.yaml** - Prometheus Stack (3 días retention)
**values/nginx-ingress-values.yaml** - NGINX Ingress (ClusterIP, forwarded headers)

### Modificar Configuración Post-Despliegue

**Escalar nodos:**
```hcl
node_desired_size = 6  # De 4 a 6
terraform apply
```

**Cambiar versión de Kubernetes:**
```hcl
cluster_version = "1.35"  # De 1.34 a 1.35
terraform apply  # Sin downtime
```

**Cambiar tipo de nodos:**
```hcl
node_instance_types = ["t3.medium"]  # De t3.small
terraform apply  # Reemplazará node group
```

**Aumentar storage de RDS:**
```hcl
db_allocated_storage = 50  # De 20GB a 50GB
terraform apply  # Sin downtime en gp3
```

## 📈 Escalabilidad y Operaciones

### Escalar Número de Nodos (Node Group Autoscaling)

El node group está configurado con:
- **Desired**: 4 nodos
- **Min**: 2 nodos
- **Max**: 6 nodos

**Escalar manualmente:**

```bash
# Ver nodos actuales
kubectl get nodes

# Cambiar en terraform.tfvars
node_desired_size = 6

# Aplicar
terraform plan
terraform apply

# Esperar 3-5 minutos para que nuevos nodos estén Ready
kubectl get nodes -w
```

**Cluster Autoscaler (opcional):**
```bash
# Automáticamente escalar basado en pods pending
# Ya está instalado en monitoring.tf pero comentado
# Para habilitarlo, descomentar en monitoring.tf

# Verificar que está corriendo
kubectl get deployment -n kube-system cluster-autoscaler
```

### Escalar Aplicaciones (Pods)

**Backend:**
```bash
# Ver réplicas actuales
kubectl get deployment backend -n retrogame

# Escalar a 3 réplicas
kubectl scale deployment backend -n retrogame --replicas=3

# Verificar nuevo estado
kubectl get pods -n retrogame | grep backend
```

**Frontend:**
```bash
kubectl scale deployment frontend -n retrogame --replicas=2
```

**Resource Limits (por pod):**
```bash
# Ver requests/limits actuales
kubectl describe deployment backend -n retrogame | grep -A 5 "Requests"

# Modificar via kubectl edit
kubectl edit deployment backend -n retrogame
# Cambiar en spec.containers[0].resources
```

### Horizontal Pod Autoscaler (HPA)

Escalar basado en CPU o memoria:

```bash
# Ver métricas actuales
kubectl top pods -n retrogame
kubectl top nodes

# Crear HPA para backend (75% CPU threshold)
kubectl autoscale deployment backend \
  -n retrogame \
  --cpu-percent=75 \
  --min=1 \
  --max=5

# Verificar HPA
kubectl get hpa -n retrogame
kubectl describe hpa backend -n retrogame

# Ver historial de escalado
kubectl get hpa -n retrogame -w
```

## 📊 Monitoreo y Troubleshooting

### Acceder a Grafana

**URL:**
```
https://retrogamehub.games/grafana/
```

**Credenciales:**
```bash
# Obtener password de admin
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
# Username: admin
```

**Dashboards disponibles:**
- Kubernetes Cluster Monitoring
- Prometheus Stats
- Node Exporter for Prometheus
- NGINX Ingress Controller

### Prometheus Queries

**URL:**
```
https://retrogamehub.games/prometheus/
```

**Queries útiles:**
```promql
# CPU usado por nodo
node_cpu_seconds_total

# Memoria disponible
node_memory_MemAvailable_bytes

# Pods por namespace
count(kube_pod_info) by (namespace)

# Pod CPU usage
container_cpu_usage_seconds_total

# Pod Memory usage
container_memory_usage_bytes
```

### CloudWatch Logs

```bash
# Ver logs de ALB
aws logs tail /aws/alb/retrogame --follow

# Ver logs de RDS
aws logs tail /aws/rds/instance/retrogame-postgres/postgresql --follow

# Ver logs de cluster
aws logs tail /aws/eks/retrogame/cluster --follow

# Buscar errores
aws logs filter-log-events \
  --log-group-name /aws/eks/retrogame/cluster \
  --filter-pattern "ERROR"
```

### Troubleshooting Común

**1. Pods en pending:**
```bash
# Ver por qué está pending
kubectl describe pod <pod-name> -n retrogame

# Posibles causas:
# - Insufficient CPU: escalar nodos
# - Insufficient memory: escalar nodos
# - Node not ready: verificar nodo
# - Image pull failed: revisar imagen en ECR
```

**2. CrashLoopBackOff:**
```bash
# Ver logs del pod
kubectl logs <pod-name> -n retrogame --previous

# Causas comunes:
# - Error en aplicación (revisar logs)
# - Falta de env vars (revisar ConfigMap/Secret)
# - Falta de permisos (revisar RBAC)
```

**3. RDS Connection Timeout:**
```bash
# Verificar que security group permite conexiones
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=eks_rds_sg"

# Verificar status de RDS
aws rds describe-db-instances \
  --db-instance-identifier retrogame-postgres \
  --query 'DBInstances[0].DBInstanceStatus'
# Output: available
```

**4. ALB no responde:**
```bash
# Verificar target health
aws elbv2 describe-target-health \
  --target-group-arn <arn>

# Verificar security groups
aws ec2 describe-security-groups \
  --group-ids <alb-sg-id>

# Verificar que NGINX Ingress Controller está corriendo
kubectl get pods -n ingress-nginx
```

**5. ArgoCD webhook error durante instalación:**
```bash
# Error: "no endpoints available for service aws-load-balancer-webhook-service"
# 
# Causa: El webhook del AWS Load Balancer Controller tarda 30-60s en estar listo
# Terraform intenta instalar ArgoCD antes de que el webhook esté operativo
#
# Solución implementada en argocd.tf:
# - Se añadió recurso time_sleep de 60s entre AWS LB Controller y ArgoCD
# - Garantiza que el webhook tenga tiempo de iniciar y registrar endpoints
#
# Verificar estado del webhook:
kubectl get endpoints -n kube-system aws-load-balancer-webhook-service

# Debe mostrar IPs en ENDPOINTS (no <none>)
# Output esperado:
# NAME                                  ENDPOINTS          AGE
# aws-load-balancer-webhook-service     10.0.1.234:9443    2m

# Verificar logs del AWS LB Controller:
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Si se necesita reinstalar ArgoCD manualmente:
helm uninstall argocd -n argocd
# Esperar 60 segundos
sleep 60
helm install argocd argo-cd/argo-cd -n argocd --create-namespace
```

### Ver Eventos del Cluster

```bash
# Eventos recientes
kubectl get events -A --sort-by='.lastTimestamp'

# Eventos de un namespace específico
kubectl get events -n retrogame

# Eventos de un pod
kubectl describe pod <pod-name> -n retrogame
```

### Logs de Kubernetes

```bash
# Pod logs
kubectl logs <pod-name> -n retrogame

# Pod logs (seguimiento en tiempo real)
kubectl logs <pod-name> -n retrogame -f

# Logs de múltiples pods
kubectl logs -n retrogame -l app=backend --tail=100

# Logs con timestamps
kubectl logs <pod-name> -n retrogame --timestamps=true
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

# Ver logs con timestamps
kubectl logs <pod-name> -n retrogame --timestamps=true
```

## Mantenimiento

### Actualizar Imágenes de Aplicaciones

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

resource "aws_acm_certificate" "retrogame" {
  domain_name       = "retrogamehub.games"
  validation_method = "DNS"
}
```

## Backend State (Configurado automáticamente)

El estado de Terraform se almacena automáticamente en S3 desde el proyecto **bootstrap**:

**Configuración actual (backend.conf):**
```hcl
bucket         = "retrogamecloud-terraform-state-<ACCOUNT_ID>"
key            = "eks/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "terraform-lock"
encrypt        = true
```

**Recursos creados por bootstrap:**
- ✅ **S3 Bucket**: `retrogamecloud-terraform-state-<ACCOUNT_ID>` (con encriptación y versionado)
- ✅ **DynamoDB Table**: `terraform-lock` (para evitar locks concurrentes)
- ✅ **Política S3**: Acceso solo a usuarios IAM autorizados
- ✅ **Bloqueo público**: Deshabilitado en bucket

**No es necesario crear recursos adicionales**, el archivo `backend.conf` simplemente hace referencia a lo ya creado en bootstrap.

### Para Equipos (Opcional: Configurar Backend Remoto Personalizado)

Si deseas usar un backend diferente al del bootstrap, puedes configurar un S3 backend personalizado en `provider.tf`:

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

**Crear recursos previos:**

```bash
aws s3 mb s3://tu-bucket-terraform-state
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

**Luego inicializar Terraform:**
```bash
terraform init -migrate-state
```
