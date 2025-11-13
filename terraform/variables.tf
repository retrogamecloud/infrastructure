variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "retrogamecloud"
}

variable "aws_region" {
  description = "Región AWS donde desplegar los recursos"
  type        = string
  default     = "eu-south-2" # ZAZ
}

variable "aws_profile" {
  description = "Perfil de AWS CLI a usar"
  type        = string
  default     = "default"
}

variable "admin_users" {
  description = "Lista de usuarios IAM con permisos de administrador"
  type        = list(string)
  default     = ["evaristogz", "naesman1", "jpalenz77", "alesisneros14"]
}
