output "cluster_name" {
  description = "Nombre del cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint del cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group del cluster EKS"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL del cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "IDs de las subnets privadas"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs de las subnets públicas"
  value       = module.vpc.public_subnets
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos RDS PostgreSQL"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.postgres.db_name
}

output "kong_load_balancer_hostname" {
  description = "Hostname del Load Balancer de Kong"
  value       = try(kubernetes_service.kong.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

output "kong_url" {
  description = "URL completa del Load Balancer de Kong"
  value       = try("http://${kubernetes_service.kong.status[0].load_balancer[0].ingress[0].hostname}", "pending")
}

output "grafana_url" {
  description = "URL pública de Grafana (LoadBalancer propio)"
  value       = "Obtener con: kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "prometheus_url" {
  description = "URL pública de Prometheus"
  value       = try("http://${kubernetes_service.kong.status[0].load_balancer[0].ingress[0].hostname}/prometheus/", "pending")
}

output "alertmanager_url" {
  description = "URL pública de AlertManager"
  value       = try("http://${kubernetes_service.kong.status[0].load_balancer[0].ingress[0].hostname}/alertmanager/", "pending")
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "node_group_security_group_id" {
  description = "Security group de los node groups"
  value       = aws_security_group.node_group.id
}

output "rds_security_group_id" {
  description = "Security group de RDS"
  value       = aws_security_group.rds.id
}

output "s3_games_bucket" {
  description = "Nombre del bucket S3 para juegos"
  value       = aws_s3_bucket.games_cdn.id
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución CloudFront"
  value       = aws_cloudfront_distribution.games_cdn.id
}

output "cloudfront_domain_name" {
  description = "Domain name de CloudFront para acceder a los juegos"
  value       = aws_cloudfront_distribution.games_cdn.domain_name
}

output "cdn_url" {
  description = "URL completa del CDN"
  value       = "https://${aws_cloudfront_distribution.games_cdn.domain_name}"
}

output "upload_games_command" {
  description = "Comando para subir juegos al bucket S3"
  value       = "aws s3 sync ./infrastructure/cdn/juegos/ s3://${aws_s3_bucket.games_cdn.id}/juegos/ --region ${var.aws_region}"
}

output "upload_images_command" {
  description = "Comando para subir imágenes al bucket S3"
  value       = "aws s3 sync ./infrastructure/cdn/img/ s3://${aws_s3_bucket.games_cdn.id}/img/ --region ${var.aws_region}"
}

<<<<<<<< HEAD:terraform/eks/outputs.tf
# ============================================================================
# Outputs de Route53 y SSL
# ============================================================================

output "route53_zone_id" {
  description = "ID de la zona Route53"
  value       = try(aws_route53_zone.main.zone_id, null)
}

output "route53_nameservers" {
  description = "Nameservers de Route53 (configurar en Namecheap)"
  value       = try(aws_route53_zone.main.name_servers, null)
}

output "ssl_certificate_arn" {
  description = "ARN del certificado SSL"
  value       = try(aws_acm_certificate.main.arn, null)
}

# ============================================================================
# Outputs de ALB
# ============================================================================

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = try(aws_lb.main.dns_name, null)
}

output "alb_zone_id" {
  description = "Zone ID del ALB"
  value       = try(aws_lb.main.zone_id, null)
}

output "domain_url" {
  description = "URL del dominio principal"
  value       = "https://retrogamehub.games"
}

# ============================================================================
# Outputs de Monitoring
# ============================================================================

output "grafana_url" {
  description = "URL de Grafana"
  value       = "https://retrogamehub.games/grafana"
}

output "prometheus_url" {
  description = "URL de Prometheus"
  value       = "https://retrogamehub.games/prometheus"
}

output "alertmanager_url" {
  description = "URL de AlertManager"
  value       = "https://retrogamehub.games/alertmanager"
}

output "grafana_admin_user" {
  description = "Usuario admin de Grafana"
  value       = "admin"
}

output "grafana_admin_password" {
  description = "Password admin de Grafana"
  value       = "admin123"
  sensitive   = true
}

output "prometheus_internal_url" {
  description = "URL interna de Prometheus Server"
  value       = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
}

output "grafana_internal_url" {
  description = "URL interna de Grafana"
  value       = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80"
}

output "alertmanager_internal_url" {
  description = "URL interna de AlertManager"
  value       = "http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093"
}

output "grafana_port_forward_command" {
  description = "Comando para acceder a Grafana localmente"
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
}

output "prometheus_port_forward_command" {
  description = "Comando para acceder a Prometheus localmente"
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
}
========
>>>>>>>> origin/main:terraform/eks/outputs2.tf.disabled
