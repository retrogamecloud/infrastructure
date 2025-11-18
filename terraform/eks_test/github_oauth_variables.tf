# ============================================================
# VARIABLES DE GITHUB OAUTH
# ============================================================
# Variables para credenciales de GitHub OAuth App

variable "github_oauth_client_id" {
  description = "Client ID de GitHub OAuth App"
  type        = string
  sensitive   = true
  
  # ⚠️ Configura esto mediante variable de entorno o terraform.tfvars:
  # export TF_VAR_github_oauth_client_id="tu_client_id"
  # 
  # O crea terraform.tfvars:
  # github_oauth_client_id = "tu_client_id"
}

variable "github_oauth_client_secret" {
  description = "Client Secret de GitHub OAuth App"
  type        = string
  sensitive   = true
  
  # ⚠️ Configura esto mediante variable de entorno o terraform.tfvars:
  # export TF_VAR_github_oauth_client_secret="tu_client_secret"
  # 
  # O crea terraform.tfvars:
  # github_oauth_client_secret = "tu_client_secret"
}
