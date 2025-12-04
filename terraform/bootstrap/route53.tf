# ============================================================================
# Route53 Hosted Zone
# ============================================================================
# 
# La Hosted Zone se crea en el bootstrap para que los nameservers sean fijos
# y no cambien cada vez que se destruye/recrea el cluster EKS.
#
# IMPORTANTE: Después de crear esta zona por primera vez, configura los 
# nameservers en tu registrador (Namecheap) con los valores de:
# terraform output route53_nameservers
#
# Los nameservers permanecerán constantes incluso si destruyes el cluster EKS.
#
# ============================================================================

# Zona DNS para retrogamehub.games
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-zone"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }

  comment = "Hosted zone for ${var.domain_name} - Managed by Terraform Bootstrap"
}
