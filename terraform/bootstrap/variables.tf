variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "RetroGameCloud"
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Perfil de AWS CLI a utilizar"
  type        = string
  default     = "retrogamecloud-terraform"
}

variable "environment" {
  description = "Entorno (dev, staging, prod)"
  type        = string
  default     = "shared"
}

variable "admin_users" {
  description = "Lista de usuarios IAM con acceso al bucket de Terraform"
  type        = list(string)
  default     = ["evaristogz", "naesman1", "jpalenz77"]
}
