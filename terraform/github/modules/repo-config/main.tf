variable "repo_name" {
  description = "Nombre del repositorio"
  type        = string
}

variable "require_status_checks" {
  description = "Si se requieren status checks en main"
  type        = bool
  default     = false
}

# Ruleset de nomenclatura de ramas
resource "github_repository_ruleset" "branch_naming" {
  repository  = var.repo_name
  name        = "Nomenclatura ramas - Estándar"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/**"]
      exclude = [
        "refs/heads/main",
        "refs/heads/master",
        "refs/heads/develop",
        "refs/heads/staging",
        "refs/heads/production"
      ]
    }
  }

  rules {
    branch_name_pattern {
      operator = "regex"
      pattern  = "^(feature|bugfix|hotfix|release|chore|docs|refactor|test|ci)/[a-z0-9-]+$"
      name     = "Usar formato: tipo/descripcion (ej: feature/user-auth, bugfix/fix-login, hotfix/security-patch)"
      negate   = false
    }
    deletion = true
  }

  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }
}

# Ruleset de protección de main
resource "github_repository_ruleset" "main_protection" {
  repository  = var.repo_name
  name        = "Protección rama - Main"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    pull_request {
      required_approving_review_count = 0
      dismiss_stale_reviews_on_push   = false
      require_code_owner_review       = false
      require_last_push_approval      = false
      required_review_thread_resolution = false
    }
    
    dynamic "required_status_checks" {
      for_each = var.require_status_checks ? [1] : []
      content {
        required_check {
          context = "tests"
        }
        strict_required_status_checks_policy = true
        do_not_enforce_on_create             = false
      }
    }
    
    deletion         = true
    non_fast_forward = true
  }

  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }
}

# Ruleset de protección de tags
resource "github_repository_ruleset" "tag_protection" {
  repository  = var.repo_name
  name        = "Protección tag - Semantic Versioning"
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/**"]
      exclude = []
    }
  }

  rules {
    tag_name_pattern {
      operator = "regex"
      pattern  = "^v[0-9]+\\.[0-9]+\\.[0-9]+(-[a-zA-Z0-9.-]+)?(\\+[a-zA-Z0-9.-]+)?$"
      name     = "Usar Semantic Versioning: vX.Y.Z (ej: v1.0.0, v2.1.3, v1.0.0-alpha, v1.0.0+build.123)"
      negate   = false
    }
    deletion = true
    update   = true
  }

  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }
}

# Labels comunes
locals {
  common_labels = {
    "auto" = {
      color       = "0E8A16"
      description = "Creado automáticamente por un workflow"
    }
    "images" = {
      color       = "0052CC"
      description = "Cambios en imágenes de Docker"
    }
    "documentation" = {
      color       = "0075ca"
      description = "Improvements or additions to documentation"
    }
    "enhancement" = {
      color       = "a2eeef"
      description = "New feature or request"
    }
    "bug" = {
      color       = "d73a4a"
      description = "Something isn't working"
    }
  }
}

resource "github_issue_label" "labels" {
  for_each = local.common_labels
  
  repository  = var.repo_name
  name        = each.key
  color       = each.value.color
  description = each.value.description
}
