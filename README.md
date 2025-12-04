# Infrastructure as Code - RetroGameCloud

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-blueviolet?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS%201.34-orange?logo=amazon)](https://aws.amazon.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Infraestructura como código (IaC) para desplegar RetroGameCloud en AWS EKS. Terraform automatiza la creación de VPC, clúster Kubernetes, base de datos, monitoreo y más.

**Documentación General:** [Ir al README Principal](https://github.com/retrogamecloud/.github/blob/main/README.md)  
**Documentación Profesional:** [Acceder a la Wiki](https://www.retrogamehub.games/wiki)

---

## Tabla de Contenidos

- [Descripción del Repositorio](#descripción-del-repositorio)
- [Funcionalidad Principal](#funcionalidad-principal)
- [Stack Tecnológico](#stack-tecnológico)
- [Instalación & Setup](#instalación--setup)
- [Estructura de Directorios](#estructura-de-directorios)
- [Variables Terraform](#variables-terraform)
- [Despliegue](#despliegue)
- [Monitoreo](#monitoreo)
- [Costos AWS](#costos-aws)
- [Troubleshooting](#troubleshooting)
- [Rollback & Limpieza](#rollback--limpieza)
- [Pipeline CI/CD](#pipeline-cicd)
- [Referencias](#referencias)

---

## Descripción del Repositorio

Este repositorio contiene toda la **infraestructura como código** para RetroGameCloud en AWS usando **Terraform**. Crea automáticamente:

✅ **VPC** con subredes públicas/privadas en 3 AZs  
✅ **EKS Cluster** (Kubernetes 1.34) con Karpenter auto-scaling  
✅ **RDS PostgreSQL** para persistencia de datos  
✅ **ALB** (Application Load Balancer) para ingress  
✅ **Route53** para DNS y certificados ACM  
✅ **Secrets Manager** para gestión de credenciales  
✅ **Grafana + Prometheus** para monitoreo  
✅ **ArgoCD** para GitOps continuous deployment  

---

## Funcionalidad Principal

### 1. Aprovisionamiento de VPC

```
┌──────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16 (eu-west-1)               │
├──────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────┐ │
│  │ Public Subnets (3 AZs)                  │ │
│  │ • 10.0.1.0/24 (eu-west-1a) - ALB       │ │
│  │ • 10.0.2.0/24 (eu-west-1b) - ALB       │ │
│  │ • 10.0.3.0/24 (eu-west-1c) - ALB       │ │
│  └─────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────┐ │
│  │ Private Subnets (3 AZs)                 │ │
│  │ • 10.0.10.0/24 (eu-west-1a) - EKS      │ │
│  │ • 10.0.11.0/24 (eu-west-1b) - EKS      │ │
│  │ • 10.0.12.0/24 (eu-west-1c) - EKS      │ │
│  └─────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────┐ │
│  │ Database Subnets (3 AZs)                │ │
│  │ • 10.0.20.0/24 (eu-west-1a) - RDS      │ │
│  │ • 10.0.21.0/24 (eu-west-1b) - RDS      │ │
│  │ • 10.0.22.0/24 (eu-west-1c) - RDS      │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### 2. EKS Cluster

- **Version:** Kubernetes 1.34
- **Nodos:** 2-10 nodos administrados por Karpenter
- **Regiones:** 3 Availability Zones (alta disponibilidad)
- **Add-ons:** VPC CNI, CoreDNS, kube-proxy

### 3. RDS PostgreSQL

- **Versión:** 15-alpine
- **Almacenamiento:** 20GB (escalable)
- **Backup:** Automático cada 7 días
- **Multi-AZ:** Sí (failover automático)

### 4. Gestión de Secretos

- **AWS Secrets Manager** para credenciales
- Integración automática con EKS
- Rotación automática de claves

> **IMPORTANTE:** Todos los secrets (API keys, contraseñas de BD, tokens JWT, credenciales, certificados) se almacenan **exclusivamente en AWS Secrets Manager** y **NO están en este repositorio**. Este repositorio de Terraform solo contiene configuración de infraestructura, sin ninguna información sensible.

### 5. Monitoreo

- **Prometheus:** Recopilación de métricas
- **Grafana:** Visualización de dashboards
- **AlertManager:** Alertas automáticas

---

## Stack Tecnológico

| Componente | Versión | Descripción |
|---|---|---|
| **Terraform** | ~1.5+ | Infrastructure as Code |
| **AWS** | Latest | Cloud provider |
| **EKS** | 1.34 | Kubernetes managed |
| **VPC** | AWS VPC | Networking (10.0.0.0/16) |
| **RDS** | PostgreSQL 15 | Database |
| **ALB** | Classic | Load balancer |
| **Route53** | AWS DNS | Domain management |
| **ACM** | AWS Certificates | SSL/TLS |
| **Secrets Manager** | AWS | Credentials |
| **Prometheus** | 2.45+ | Metrics collection |
| **Grafana** | 10.0+ | Dashboards |
| **ArgoCD** | 2.10+ | GitOps |

### Módulos Terraform

```
terraform/
├── eks/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── karpenter.tf
│   ├── iam-roles.tf
│   └── security-groups.tf
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── nat-gateway.tf
│   └── route-tables.tf
├── rds/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── alb/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── route53/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── monitoring/
│   ├── main.tf
│   ├── prometheus.tf
│   ├── grafana.tf
│   └── alerting.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── backend.tf
```

### Workflows CI/CD

| Workflow | Trigger | Descripción |
|---|---|---|
| **validate-and-scan.yml** | Push a cualquier rama | Terraform fmt/validate, Trivy IaC scan, SonarCloud |
| **dependabot.yml** | Scheduled (diario) | Actualiza GitHub Actions, Terraform modules, npm packages |

---

## Instalación & Setup

### Requisitos Previos

```bash
# Verificar Terraform
terraform --version
# Terraform v1.5+

# Verificar AWS CLI
aws --version
# aws-cli/2.13+

# Verificar kubectl
kubectl version
# v1.34+
```

### Paso 1: Clonar el Repositorio

```bash
git clone https://github.com/retrogamecloud/infrastructure.git
cd infrastructure/terraform
```

### Paso 2: Configurar AWS Credentials

```bash
# Opción 1: AWS CLI
aws configure
# Ingresar: AWS Access Key ID, Secret Access Key, region (eu-west-1)

# Opción 2: Variables de entorno
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"

# Opción 3: IAM Role (en EC2)
# Se detecta automáticamente
```

### Paso 3: Inicializar Terraform

```bash
# Crear backend S3 (opcional pero recomendado)
# Ver: backend.tf

# Inicializar
terraform init

# Verificar archivos descargados
ls -la .terraform/
```

### Paso 4: Validar Configuración

```bash
terraform validate
# Success! The configuration is valid.

# Planificar cambios (sin aplicar)
terraform plan -out=tfplan

# Revisar cambios
# AWS resources to add: 50+
# AWS resources to modify: 0
# AWS resources to destroy: 0
```

### Paso 5: Aplicar Infraestructura

```bash
# IMPORTANTE: Revisar el plan anterior primero

# Aplicar cambios (toma 20-30 minutos)
terraform apply tfplan

# Confirmación:
# Do you want to perform these actions? yes
# Apply complete! Resources: 50 added, 0 changed, 0 destroyed.
```

### Paso 6: Configurar kubeconfig

```bash
# Actualizar kubeconfig para conectarse a EKS
aws eks update-kubeconfig \
  --name retrogame-cluster \
  --region eu-west-1

# Verificar conexión
kubectl get nodes
# Debería listar nodos del cluster EKS
```

---

## Estructura de Directorios

```
infrastructure/
├── .github/
│   ├── dependabot.yml             # Configuración de Dependabot
│   └── workflows/
│       └── validate-and-scan.yml # Validación de Terraform + Trivy
│
├── terraform/
│   ├── bootstrap/               # Configuración inicial (S3, DynamoDB, IAM)
│   │   ├── s3-tfstate.tf       # Bucket S3 para remote state
│   │   ├── dynamodb.tf         # DynamoDB para state locking
│   │   ├── iam.tf              # Roles y políticas
│   │   ├── data.tf
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── README.md
│   │   └── .gitignore
│   ├── eks/
│   │   ├── main.tf             # Definición del cluster EKS
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── karpenter.tf        # Auto-scaling con Karpenter
│   │   ├── iam-roles.tf
│   │   └── security-groups.tf
│   ├── github/                 # Configuración de GitHub (secrets, tokens)
│   │   ├── main.tf
│   │   ├── modules/
│   │   ├── README.md
│   │   └── .gitignore
│   ├── main.tf                 # Orquestación principal
│   ├── variables.tf            # Variables globales
│   ├── outputs.tf
│   ├── terraform.tfvars        # Valores específicos
│   └── backend.tf              # Remote state (S3)
├── cdn/                        # Configuración de CDN (nginx)
├── monitoring/                 # Configuración de monitoreo
├── argocd/                     # Configuración de GitOps (Argo CD)
├── tests/
│   ├── terraform_test.sh
│   └── README.md
└── README.md (this file)
```

---

## Variables Terraform

### Configuración Principal (terraform.tfvars)

```hcl
# AWS
aws_region = "eu-west-1"
environment = "production"

# Cluster EKS
cluster_name = "retrogame-cluster"
cluster_version = "1.34"
kubernetes_network_cidr = "10.100.0.0/16"

# VPC
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

# Nodos EKS
desired_capacity = 3
min_size = 2
max_size = 10
instance_types = ["t3.medium", "t3.large"]

# RDS PostgreSQL
db_instance_class = "db.t3.small"
allocated_storage = 20
engine_version = "15.3"

# Route53
domain_name = "retrogamehub.games"

# Monitoreo
enable_prometheus = true
enable_grafana = true
grafana_admin_password = "SecurePassword123!"

# Costos
enable_cost_monitoring = true
# budget_alert_email = configurar según necesidad
```

### Variables con Valores por Defecto

```hcl
variable "aws_region" {
  description = "AWS region (default: eu-west-1)"
  type = string
  default = "eu-west-1"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type = string
  default = "1.34"
}

variable "cluster_name" {
  description = "Nombre del cluster EKS"
  type = string
  default = "retrogame-cluster"
}
```

---

## Despliegue

### Despliegue Completo (Producción)

```bash
# 1. Validar
terraform validate

# 2. Planificar
terraform plan -out=tfplan

# 3. Revisar plan (IMPORTANTE)
# Verificar que no elimina recursos críticos

# 4. Aplicar
terraform apply tfplan

# 5. Esperar 20-30 minutos
# CloudFormation creando recursos

# 6. Obtener endpoint del cluster
terraform output -raw kubernetes_endpoint

# 7. Conectar kubectl
aws eks update-kubeconfig \
  --name retrogame-cluster \
  --region eu-west-1

# 8. Verificar
kubectl get nodes
kubectl get pods -A

# 9. Desplegar aplicaciones (ArgoCD)
# Ver: kubernetes/README.md
```

### Despliegue Modular

```bash
# Solo VPC
cd terraform/vpc
terraform init
terraform apply

# Solo EKS (requiere VPC)
cd ../eks
terraform init
terraform apply

# Solo RDS (requiere VPC)
cd ../rds
terraform init
terraform apply

# Solo Monitoreo
cd ../monitoring
terraform init
terraform apply
```

---

## Monitoreo

### Prometheus

```bash
# Acceder a Prometheus
kubectl port-forward -n prometheus svc/prometheus 9090:9090
# http://localhost:9090
```

**Métricas principales:**
- `node_cpu_seconds_total` - CPU del nodo
- `node_memory_MemAvailable_bytes` - Memoria disponible
- `kubelet_running_pods` - Pods ejecutándose
- `http_request_duration_seconds` - Latencia HTTP

### Grafana

```bash
# Acceder a Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# http://localhost:3000
# Usuario: admin
# Contraseña: (ver en Secrets Manager)
```

**Dashboards:**
- Kubernetes Cluster Monitoring
- Node Exporter Full
- PostgreSQL Database
- Kong API Gateway

### AlertManager

```bash
# Alertas configuradas:
# - CPU > 80%
# - Memoria > 85%
# - Pods pendientes > 5
# - Pod CrashLoopBackOff
```

---

## Costos AWS

### Desglose por Servicio

| Servicio | Dev | Producción |
|----------|-----|-----------|
| **EKS** | $73 | $73 |
| **EC2 (Nodos t3)** | $30 | $120 |
| **RDS** | $28 | $85 |
| **ALB** | $16 | $16 |
| **NAT Gateway** | $10 | $32 |
| **Route53** | $0.50 | $0.50 |
| **VPC Endpoints** | $0 | $14.40 |
| **Data Transfer** | $0 | $5 |
| **Otros** | $10 | $60 |
| **TOTAL/mes** | ~$166-206 | ~$401-601 |

### Estimación Anual

```
Development:  $1,992 - $2,472
Production:   $4,812 - $7,212
```

### Optimizaciones Costos

```hcl
# 1. Usar Spot Instances (60% descuento)
instance_types = ["t3.medium", "t3.large"]
spot_percentage = 100  # Cambiar a 70% para estabilidad

# 2. Reducir tamaño DB en dev
db_instance_class = "db.t3.micro"  # en lugar de small

# 3. Limitar almacenamiento
allocated_storage = 20  # en lugar de 100

# 4. Desactivar monitoreo en dev
enable_prometheus = false
enable_grafana = false

# 5. Usar NAT Instance (vs NAT Gateway)
use_nat_instance = true  # Ahorrar $32/mes
```

---

## Troubleshooting

### Error: VPC Limit Exceeded

```bash
# Problema: AWS VPC limit por región
# Solución: Usar VPC existente o aumentar límite

# Ver límites
aws service-quotas list-service-quotas \
  --service-code vpc

# Solicitar aumento
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code VPC_PER_REGION \
  --desired-value 10
```

### Error: IAM Permission Denied

```bash
# Problema: Usuario sin permisos en AWS
# Verificar política

aws iam get-user
aws iam list-attached-user-policies --user-name <user>

# Politica requerida: AdministratorAccess (o más específica)
```

### EKS Nodes No Aparecen

```bash
# Problema: Karpenter no crea nodos
# Verificar

kubectl get nodes
# Si está vacío:

# 1. Ver logs de Karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# 2. Ver eventos
kubectl describe node

# 3. Verificar recursos
kubectl top nodes

# 4. Reiniciar Karpenter
kubectl rollout restart -n karpenter deployment/karpenter
```

### RDS Connection Error

```bash
# Problema: No conecta a PostgreSQL
# Verificar security group

aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=rds-sg"

# Añadir ingress para EKS
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxx \
  --protocol tcp \
  --port 5432 \
  --source-security-group-id sg-yyy
```

---

## Rollback & Limpieza

### Destruir Toda la Infraestructura

```bash
# CUIDADO: Elimina TODOS los recursos AWS

terraform destroy

# Confirmación:
# Do you really want to destroy all resources? yes

# Esperar 10-15 minutos
```

### Destruir Recurso Específico

```bash
# Eliminar solo RDS (conservar EKS/VPC)
terraform destroy -target=module.rds

# Eliminar ALB
terraform destroy -target=module.alb

# Eliminar monitoreo
terraform destroy -target=module.monitoring
```

### Rollback a Versión Anterior

```bash
# Ver historial de cambios
terraform show

# Restaurar estado anterior
terraform state pull > backup.tfstate

# Aplicar estado anterior
terraform state push old.tfstate

# Reconciliar
terraform plan
terraform apply
```

### Limpiar Estado Local

```bash
# Backup del estado actual
cp terraform.tfstate terraform.tfstate.backup

# Limpiar caché
rm -rf .terraform
rm -rf .terraform.lock.hcl

# Reinicializar
terraform init
```

---

## Pipeline CI/CD

Este repositorio implementa validaciones automáticas mediante GitHub Actions para asegurar la calidad y seguridad de las configuraciones de infraestructura como código.

### Validaciones Automáticas

Cada vez que haces un push o abres un Pull Request, se ejecutan automáticamente:

✅ **Terraform Linting:** `terraform fmt` y `terraform validate` en todos los directorios  
✅ **Validación:** `terraform init` verifica configuración y plugins  
✅ **Escaneo de Vulnerabilidades:** Trivy escanea el código Terraform  
✅ **Análisis Estático:** SonarCloud detecta misconfigurations y problemas de IaC  
✅ **ArgoCD:** Validación de manifiestos GitOps  
✅ **Notificaciones:** Slack alertas para fallos críticos en validaciones  

### Workflows Disponibles

| Workflow | Trigger | Descripción |
|---|---|---|
| **validate-and-scan.yml** | Push a `main`, PR | Validación Terraform, seguridad y análisis estático |
| **dependabot.yml** | Scheduled (diario) | Mantener dependencias y providers actualizados |

**Documentación detallada:** Ver [`.github/README-WF.md`](./.github/README-WF.md) para más información sobre cada workflow, triggers, variables y secrets.

---

## Referencias

### Documentación Oficial
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Documentation](https://karpenter.sh/docs/)

### Documentación del Proyecto
- **Workflows CI/CD:** [.github/README-WF.md](./.github/README-WF.md)
- **Secretos & Seguridad:** [SECRETS-STRATEGY.md](../.github/docs/SECRETS-STRATEGY.md)
- **Documentación General:** [/README.md](/../README.md)

### Repositorios Relacionados
- [Backend API](https://github.com/retrogamecloud/backend/blob/main/README.md)
- [Frontend](https://github.com/retrogamecloud/frontend/blob/main/README.md)
- [Kong Gateway](https://github.com/retrogamecloud/kong/blob/main/README.md)
- [Kubernetes Manifests](https://github.com/retrogamecloud/kubernetes/blob/main/README.md)
- [Documentación Centralizada](https://github.com/retrogamecloud/docs)

### Documentación Externa
- [Terraform Cloud Console](https://app.terraform.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Documentation](https://karpenter.sh/docs/)

---

**Última actualización:** 1 de diciembre de 2025  
**Versión:** 1.0  
**Mantenedor:** RetroGameCloud DevOps Team
