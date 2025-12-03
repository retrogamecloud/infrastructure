terraform {
  cloud {
    organization = "retrogamecloud"

    workspaces {
      name = "github-config"
    }
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
}

# Añadir configuración adicional para forzar el owner
variable "github_owner" {
  description = "GitHub organization owner"
  type        = string
  default     = "retrogamecloud"
}

# Variables
variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "repos" {
  description = "Lista de repositorios a gestionar"
  type        = list(string)
  default     = ["backend", "frontend", "kubernetes", "docs", "infrastructure", "kong"]
}

# Módulo reutilizable para repos
module "repos" {
  source   = "./modules/repo-config"
  for_each = toset(var.repos)

  repo_name             = each.key
  require_status_checks = contains(["backend", "frontend", "docs"], each.key)
}
