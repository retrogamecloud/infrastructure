# ============================================================================
# Outputs relacionados con ALB, Route53 y oauth2
# ============================================================================

# ALB
output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID del ALB para Route53"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.main.arn
}

# Route53
output "route53_nameservers" {
  description = "Nameservers de Route53 - Configúralos en Namecheap"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "Nombre del dominio principal"
  value       = "retrogamehub.games"
}

# URLs de acceso
output "frontend_url" {
  description = "URL pública del frontend"
  value       = "https://retrogamehub.games"
}

output "grafana_url_with_auth" {
  description = "URL de Grafana (protegida con GitHub OAuth)"
  value       = "https://retrogamehub.games/grafana"
}

output "prometheus_url_with_auth" {
  description = "URL de Prometheus (protegida con GitHub OAuth)"
  value       = "https://retrogamehub.games/prometheus"
}

output "alertmanager_url_with_auth" {
  description = "URL de AlertManager (protegida con GitHub OAuth)"
  value       = "https://retrogamehub.games/alertmanager"
}

# OAuth2-Proxy
output "oauth2_proxy_target_group_arn" {
  description = "ARN del Target Group de oauth2-proxy"
  value       = aws_lb_target_group.oauth2_proxy.arn
}

# Certificado SSL
output "ssl_certificate_arn" {
  description = "ARN del certificado SSL"
  value       = aws_acm_certificate.main.arn
}

output "ssl_certificate_status" {
  description = "Estado de la validación del certificado SSL"
  value       = aws_acm_certificate.main.status
}

# Security Groups
output "alb_security_group_id" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb.id
}

# Target Groups
output "target_group_arns" {
  description = "ARNs de todos los Target Groups"
  value = {
    frontend     = aws_lb_target_group.frontend.arn
    oauth2_proxy = aws_lb_target_group.oauth2_proxy.arn
    grafana      = aws_lb_target_group.grafana.arn
    prometheus   = aws_lb_target_group.prometheus.arn
    alertmanager = aws_lb_target_group.alertmanager.arn
  }
}

# Instrucciones de configuración
output "setup_instructions" {
  description = "Instrucciones para completar la configuración"
  value       = <<-EOT
    ================================================
    📋 PASOS PARA COMPLETAR LA CONFIGURACIÓN
    ================================================
    
    1️⃣ CREAR GITHUB OAUTH APP:
       1. Ve a: https://github.com/settings/developers
       2. Click en "New OAuth App"
       3. Completa:
          - Application name: Retrogame Monitoring
          - Homepage URL: https://retrogamehub.games
          - Callback URL: https://retrogamehub.games/oauth2/callback
       4. Guarda el Client ID y Client Secret
    
    2️⃣ CONFIGURAR VARIABLES DE TERRAFORM:
       export TF_VAR_github_oauth_client_id="tu_client_id"
       export TF_VAR_github_oauth_client_secret="tu_client_secret"
    
    3️⃣ CONFIGURAR NAMESERVERS EN NAMECHEAP:
       Ve a Namecheap → Manage Domain → Advanced DNS
       Cambia los nameservers a:
       ${join("\n       ", aws_route53_zone.main.name_servers)}
    
    4️⃣ ESPERAR PROPAGACIÓN DNS (puede tomar hasta 48h, pero usualmente < 1h)
       Verifica con: dig retrogamehub.games
    
    5️⃣ ACCEDER A LAS URLS:
       • Frontend:      https://retrogamehub.games (público)
       • Grafana:       https://retrogamehub.games/grafana (requiere GitHub login)
       • Prometheus:    https://retrogamehub.games/prometheus (requiere GitHub login)
       • AlertManager:  https://retrogamehub.games/alertmanager (requiere GitHub login)
    
    6️⃣ PRIMER LOGIN:
       Al acceder a Grafana/Prometheus/AlertManager serás redirigido a GitHub
       para hacer login. Autoriza la aplicación y serás redirigido de vuelta.
       
    📚 DOCUMENTACIÓN COMPLETA: Ver GITHUB_OAUTH_SETUP.md
    ================================================
  EOT
}
