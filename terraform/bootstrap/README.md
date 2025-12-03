# Terraform Bootstrap

## Descripción

Proyecto especializado para crear la infraestructura base (backend) necesaria para gestionar el estado de Terraform de forma remota y centralizada. Proporciona almacenamiento seguro en S3, control de concurrencia mediante DynamoDB locks, y gestión de usuarios IAM con acceso controlado.

Este bootstrap es el punto de entrada para toda la infraestructura de RetroGameCloud. Debe ejecutarse primero antes que cualquier otro proyecto Terraform.

## Tabla de contenidos

- [Descripción](#descripción)
- [Qué crea](#qué-crea)
- [Prerequisitos](#prerequisitos)
- [Guía de despliegue](#guía-de-despliegue)
- [Configuración](#configuración)
- [Administración](#administración)
- [Recuperación](#recuperación)
- [Seguridad](#seguridad)

## Qué crea

### Infraestructura de Backend S3

**Bucket S3 para Terraform State**
- Nombre: `retrogamecloud-terraform-state-<ACCOUNT_ID>`
- Encriptación: AES256 por defecto
- Versionado: Habilitado para recuperación de estados anteriores
- Acceso público: Bloqueado completamente
- Política de bucket: Permite acceso solo a usuarios IAM especificados
- Protección: `prevent_destroy = true` para evitar eliminaciones accidentales

**Características de seguridad S3**
```
- block_public_acls       = true
- block_public_policy     = true
- ignore_public_acls      = true
- restrict_public_buckets = true
```

### Tabla DynamoDB para State Locking

**Tabla DynamoDB**
- Nombre: `terraform-lock`
- Modo de facturación: PAY_PER_REQUEST (sin costos si no se usa)
- Clave hash: `LockID` (String)
- Propósito: Prevenir ejecuciones concurrentes de Terraform
- Ciclo de vida: Permite destrucción (a diferencia de S3)

**Política IAM para DynamoDB**
```
- dynamodb:GetItem
- dynamodb:PutItem
- dynamodb:DeleteItem
- dynamodb:DescribeTable
```

### Gestión de Usuarios IAM

**Grupo de Administradores**
- Nombre: `Administrators`
- Política: `AdministratorAccess` (acceso total)
- Miembros: Todos los usuarios especificados en `admin_users`

**Usuario Terraform (Especial)**
- Nombre: `retrogamecloud-terraform`
- Permisos: AdministratorAccess
- Protección: `force_destroy = false` (permanente)
- Uso: Ejecución de Terraform en CI/CD pipelines

**Usuarios Administradores (Variables)**
- Nombres: Especificados en variable `admin_users`
- Por defecto: `["evaristogz", "naesman1", "jpalenz77"]`
- Permisos: AdministratorAccess
- Credenciales: Contraseña + Access Keys automáticas

### Estructura de archivos

```
bootstrap/
├── provider.tf              # Configuración de AWS (v5.0+), Terraform v1.5+
├── variables.tf             # Variables de entrada (región, usuarios, proyecto)
├── data.tf                  # Data source de account ID
├── s3-tfstate.tf            # Bucket S3 + versionado + encriptación
├── dynamodb.tf              # Tabla de locks + política IAM
├── iam.tf                   # Usuarios + grupo + políticas
├── outputs.tf               # Valores de salida para uso en otros proyectos
├── terraform.tfstate        # Estado local (NO en git)
└── README.md                # Este archivo
```

## Prerequisitos

- **AWS Account** con acceso root o credenciales de administrador
- **Terraform** 1.5 o superior
- **AWS CLI** v2 configurado con credenciales
- **Permisos IAM mínimos** para crear S3, DynamoDB, IAM
  - `s3:*`
  - `dynamodb:*`
  - `iam:*`

**Verificar configuración de AWS**
```bash
aws sts get-caller-identity
# Respuesta esperada:
# {
#   "UserId": "AIDAI...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/mi-usuario"
# }
```

## Guía de despliegue

### Paso 1: Revisar variables

```bash
cd infrastructure/terraform/bootstrap

# Ver configuración por defecto
cat variables.tf
```

**Variables configurables:**
| Variable | Defecto | Descripción |
|----------|---------|-------------|
| `project_name` | RetroGameCloud | Nombre del proyecto para tags |
| `aws_region` | eu-west-1 | Región AWS |
| `aws_profile` | retrogamecloud-terraform | Perfil de AWS |
| `environment` | shared | Entorno (shared para bootstrap) |
| `admin_users` | ["evaristogz", "naesman1", "jpalenz77"] | Lista de usuarios IAM |

**Personalizar variables (opcional):**
```bash
# Opción 1: Crear archivo terraform.tfvars
cat > terraform.tfvars <<EOF
admin_users = ["usuario1", "usuario2", "usuario3"]
aws_region = "us-east-1"
EOF

# Opción 2: Pasar como flag
terraform plan -var 'admin_users=["nuevo-admin"]'
```

### Paso 2: Inicializar Terraform

```bash
terraform init

# Salida esperada:
# Initialized Terraform working directory
# Backend type: local
# Changes to Outputs will be forced to recompute
```

### Paso 3: Revisar plan

```bash
terraform plan

# Salida esperada (resumida):
# Plan: 17 to add, 0 to change, 0 to destroy
# 
# Recursos:
# - aws_s3_bucket
# - aws_s3_bucket_versioning
# - aws_s3_bucket_server_side_encryption_configuration
# - aws_s3_bucket_public_access_block
# - aws_s3_bucket_policy
# - aws_dynamodb_table
# - aws_iam_policy (DynamoDB access)
# - aws_iam_group (Administrators)
# - aws_iam_group_policy_attachment (AdministratorAccess)
# - aws_iam_user (retrogamecloud-terraform)
# - aws_iam_user (otros usuarios)
# - aws_iam_user_group_membership (x3)
# - aws_iam_user_policy_attachment (x3)
# - aws_iam_access_key (x2)
# - aws_iam_user_login_profile (x2)
```

### Paso 4: Aplicar configuración

```bash
terraform apply

# Solicitará confirmación:
# Do you want to perform these actions?
# Type 'yes' to continue

# Salida esperada:
# Apply complete! Resources: 17 added, 0 changed, 0 destroyed.
# 
# Outputs:
# terraform_state_bucket = "retrogamecloud-terraform-state-123456789012"
# terraform_lock_table = "terraform-lock"
# aws_region = "eu-west-1"
# next_steps = [instrucciones]
```

### Paso 5: Guardar outputs críticos

```bash
# Ver todos los outputs
terraform output

# Copiar el nombre del bucket (necesario para otros proyectos)
terraform output -raw terraform_state_bucket

# Guardar en archivo de referencia
terraform output -raw terraform_state_bucket > ../.terraform-backend-bucket.txt
```

### Resumen rápido

```bash
cd infrastructure/terraform/bootstrap
terraform init
terraform plan
terraform apply
terraform output
```

## Configuración

### Variables de entrada

**provider.tf**
```hcl
variable "aws_region" {
  default = "eu-west-1"
}

variable "aws_profile" {
  default = "retrogamecloud-terraform"
}

variable "environment" {
  default = "shared"
}

variable "project_name" {
  default = "RetroGameCloud"
}

variable "admin_users" {
  default = ["evaristogz", "naesman1", "jpalenz77"]
}
```

### S3 Backend en otros proyectos

Una vez creado el bootstrap, usa este backend en tus proyectos (ej: eks_test, rds, etc):

**Estructura recomendada:**
```
projects/
├── bootstrap/                   ← Este proyecto
├── eks_test/
│   └── provider.tf
├── rds/
│   └── provider.tf
└── networking/
    └── provider.tf
```

**Configurar provider.tf en cada proyecto:**
```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "retrogamecloud-terraform-state-123456789012"  # Output del bootstrap
    key            = "eks_test/terraform.tfstate"                   # Cambiar por proyecto
    region         = "eu-west-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
    profile        = "retrogamecloud-terraform"
  }
}

provider "aws" {
  region  = "eu-west-1"
  profile = "retrogamecloud-terraform"
  
  default_tags {
    tags = {
      Project     = "RetroGameCloud"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }
}
```

**Inicializar con el backend remoto:**
```bash
cd projects/eks_test
terraform init

# Cuando pregunte sobre migrar estado local:
# Do you want to copy existing state to the new backend?
# > yes

# Verificar que el estado está en S3
aws s3 ls s3://retrogamecloud-terraform-state-123456789012/
# PRE eks_test/
```

## Administración

### Obtener credenciales de usuarios

**Descomentar outputs en outputs.tf (opcional)**
```bash
# Los outputs están comentados por razones de seguridad
# Para ver credenciales, descomentar en outputs.tf:

terraform output -json user_passwords | jq '.'
terraform output -json user_access_keys | jq '.'
```

### Agregar nuevo usuario

**Editar variables.tf:**
```hcl
variable "admin_users" {
  default = ["evaristogz", "naesman1", "jpalenz77", "nuevo-usuario"]
}
```

**Aplicar cambios:**
```bash
terraform plan
terraform apply

# Plan: 4 to add (usuario + access key + login profile + iam attachment)
```

### Rotar credenciales de usuarios

```bash
# Regenerar access keys para un usuario
terraform state rm 'aws_iam_access_key.keys["usuario-a-rotar"]'
terraform apply

# Regenerar login profile (contraseña)
terraform state rm 'aws_iam_user_login_profile.user_passwords["usuario-a-rotar"]'
terraform apply
```

### Eliminar usuario

**Editar variables.tf:**
```hcl
variable "admin_users" {
  default = ["evaristogz", "naesman1"]  # Remover jpalenz77
}
```

**Aplicar cambios:**
```bash
terraform apply

# Destroy: 3 (user + access key + login profile + iam attachment)
```

### Ver estado actual

```bash
# Listar todos los recursos creados
terraform state list

# Inspeccionar un recurso específico
terraform state show aws_s3_bucket.terraform_state

# Ver información del bucket
aws s3 ls s3://retrogamecloud-terraform-state-123456789012/

# Ver tabla DynamoDB
aws dynamodb describe-table --table-name terraform-lock
```

## Recuperación

### Backup del estado local

```bash
# Este proyecto usa estado LOCAL (archivo terraform.tfstate)
# IMPORTANTE: Hacer backup manual

# Opción 1: Copiar a almacenamiento seguro
cp terraform.tfstate ~/Backups/terraform-bootstrap-$(date +%Y%m%d).tfstate

# Opción 2: Subir a S3 personal (NO el bucket de Terraform)
aws s3 cp terraform.tfstate s3://mi-backup-personal/terraform-bootstrap.tfstate

# Opción 3: Guardar en repositorio (con encriptación)
git crypt add-gpg-user email@example.com
git add terraform.tfstate
git commit -m "Backup de estado bootstrap"
```

### Recuperar desde backup

```bash
# Si se elimina terraform.tfstate accidentalmente
cp ~/Backups/terraform-bootstrap-20231201.tfstate terraform.tfstate

# Verificar integridad
terraform validate

# Sincronizar con AWS (si hay diferencias)
terraform plan
terraform apply
```

### Destruir y recrear bucket

```bash
# CUIDADO: Esto elimina TODO el estado de Terraform
# Solo usar en caso de emergencia

# 1. Hacer backup COMPLETO
aws s3 sync s3://retrogamecloud-terraform-state-123456789012/ ./backup/

# 2. Vaciar bucket
aws s3 rm s3://retrogamecloud-terraform-state-123456789012/ --recursive

# 3. Destruir recursos
terraform destroy

# 4. Recrear
terraform apply
```

### Recuperar estado de versiones anteriores

```bash
# S3 tiene versionado habilitado
# Ver versiones disponibles
aws s3api list-object-versions \
  --bucket retrogamecloud-terraform-state-123456789012 \
  --prefix eks_test/terraform.tfstate

# Restaurar versión anterior
aws s3api get-object \
  --bucket retrogamecloud-terraform-state-123456789012 \
  --key eks_test/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.old
```

## Seguridad

### Protección de credenciales

**No exponer en versión control:**
```bash
# El archivo .gitignore incluye:
terraform.tfstate
terraform.tfstate.backup
*.tfvars
!example.tfvars
.terraform/
```

**Usuario terraform-terraform (protegido):**
```hcl
resource "aws_iam_user" "terraform_user" {
  force_destroy = false  # No se puede eliminar accidentalmente
}
```

**Access Keys:**
- Se generan automáticamente
- Se guardan en `terraform.tfstate` (proteger este archivo)
- Rotar cada 90 días
- No compartir por email o chat

### Control de acceso IAM

**Bucket S3:**
```hcl
"Principal": {
  "AWS": [
    "arn:aws:iam::123456789012:user/evaristogz",
    "arn:aws:iam::123456789012:user/naesman1",
    "arn:aws:iam::123456789012:user/jpalenz77"
  ]
}
```

**DynamoDB:**
- Solo usuarios del grupo `Administrators` tienen acceso
- Vía política adjunta al grupo

**Encriptación S3:**
```
- server_side_encryption: AES256
- bucket_key_enabled: true (en CloudTrail)
```

### Auditoría

**CloudTrail (recomendado):**
```bash
# Habilitar CloudTrail para auditar cambios
aws cloudtrail create-trail --name terraform-audit --s3-bucket-name my-audit-bucket

# Ver cambios en S3
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=retrogamecloud-terraform-state
```

**Logs de Terraform:**
```bash
export TF_LOG=DEBUG
terraform apply
# Guardará logs muy detallados (archivo terraform-debug.log)
```

### Límites y advertencias

⚠️ **CRÍTICO: NUNCA ejecutes `terraform destroy` en este proyecto**
- Eliminaría el bucket S3 (protegido con `prevent_destroy = true`, fallará)
- Eliminaría la tabla DynamoDB (permitida)
- Eliminaría todos los usuarios IAM
- Los estados de otros proyectos quedarían huérfanos

**Si necesitas destruir (emergencia):**
```bash
# 1. Backup completo del bucket
aws s3 sync s3://retrogamecloud-terraform-state-<ACCOUNT_ID>/ ./final-backup/

# 2. Cambiar configuración de protección
# Editar s3-tfstate.tf:
#   prevent_destroy = false
terraform apply

# 3. AHORA sí destruir
terraform destroy
```

**Costos:**
- Bucket S3: ~$0.023/GB/mes
- DynamoDB (PAY_PER_REQUEST): ~$1.25/millón de escrituras
- IAM Users: Gratis (solo almacenamiento de credenciales)
- Versionado S3: Costo adicional por versiones antiguas
