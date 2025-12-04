variable "aws_region" {
  description = "AWS region para el despliegue"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Perfil de AWS CLI a utilizar"
  type        = string
  default     = "retrogamecloud-terraform"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "RetroGameCloud"
}

variable "environment" {
  description = "Entorno de despliegue (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Nombre del cluster EKS"
  type        = string
  default     = "retrogame"
}

variable "cluster_version" {
  description = "Versión de Kubernetes para EKS"
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "private_subnets" {
  description = "CIDR blocks para subnets privadas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "CIDR blocks para subnets públicas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 para los nodos"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Número deseado de nodos"
  type        = number
  default     = 4
}

variable "node_min_size" {
  description = "Número mínimo de nodos"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Número máximo de nodos"
  type        = number
  default     = 6
}

variable "enable_cluster_autoscaler" {
  description = "Habilitar Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Habilitar Metrics Server"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Habilitar AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "Clase de instancia para RDS PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage asignado para RDS (GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "retrogamedb"
}

# ============================================================================
# SECRETOS MOVIDOS A AWS SECRETS MANAGER
# ============================================================================
#
# Las siguientes variables han sido ELIMINADAS y ahora se leen desde
# AWS Secrets Manager usando data sources en secrets-data.tf
#
# Secretos gestionados en AWS Secrets Manager:
#   - prod/retrogame/db-username
#   - prod/retrogame/db-password
#   - prod/retrogame/jwt-secret
#   - prod/retrogame/github-oauth (JSON: client_id, client_secret)
#   - prod/retrogame/github-token
#   - prod/retrogame/slack-bot-token
#   - prod/retrogame/slack-webhook-url
#
# Los valores se leen automáticamente mediante locals definidos en secrets-data.tf:
#   - local.db_username
#   - local.db_password
#   - local.jwt_secret
#   - local.github_oauth_client_id
#   - local.github_oauth_client_secret
#   - local.github_token
#   - local.slack_bot_token
#   - local.slack_webhook_url
#
# ============================================================================

variable "db_username" {
  description = "Usuario de la base de datos"
  type        = string
  default     = "retrogame"
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret para JWT"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags adicionales para recursos"
  type        = map(string)
  default     = {}
}

variable "slack_webhook_url" {
  description = "Webhook URL de Slack para alertas de AlertManager"
  type        = string
  sensitive   = true
}

# ============================================================================
# NOTA: Los secretos OAuth se gestionan directamente en AWS Secrets Manager
# No se requieren variables en Terraform, se leen mediante data sources
# ============================================================================

variable "github_token" {
  description = "GitHub Personal Access Token para ArgoCD repository access"
  type        = string
  sensitive   = true
}

variable "slack_bot_token" {
  description = "Slack Bot Token para notificaciones de ArgoCD (xoxb-...)"
  type        = string
  sensitive   = true
}

