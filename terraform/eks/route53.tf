# ============================================================================
# Route53 & SSL Certificate
# ============================================================================
# 
# IMPORTANTE: Después de crear esta zona, debes actualizar los nameservers 
# en Namecheap con los valores de aws_route53_zone.main.name_servers
#
# ============================================================================

# Zona DNS para retrogamehub.games
resource "aws_route53_zone" "main" {
  name = "retrogamehub.games"

  tags = {
    Name        = "retrogamehub-zone"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }
}

# Certificado SSL para HTTPS (válido para dominio y wildcard)
resource "aws_acm_certificate" "main" {
  domain_name       = "retrogamehub.games"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.retrogamehub.games"
  ]

  tags = {
    Name        = "retrogamehub-cert"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Validación del certificado vía DNS
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# Esperar a que el certificado sea validado
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}

# Registro A para el dominio principal apuntando al ALB
resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "retrogamehub.games"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
}

# Registro A wildcard para subdominios (opcional)
resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "*.retrogamehub.games"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
}
