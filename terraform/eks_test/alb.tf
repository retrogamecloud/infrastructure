# ============================================================================
# Application Load Balancer (ALB)
# ============================================================================
#
# ALB con path-based routing:
# - /                   → Frontend (público)
# - /oauth2/*           → OAuth2-proxy (GitHub authentication)
# - /grafana/*          → Grafana (protegido con GitHub OAuth)
# - /prometheus/*       → Prometheus (protegido con GitHub OAuth)
# - /alertmanager/*     → AlertManager (protegido con GitHub OAuth)
#
# ============================================================================

# Security Group para el ALB
resource "aws_security_group" "alb" {
  name_prefix = "retrogame-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # HTTP (redirigir a HTTPS)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from internet"
  }

  # Egress - permitir todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "retrogame-alb-sg"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "retrogame-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "retrogame-alb"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }
}

# ============================================================================
# Target Groups
# ============================================================================

# Target Group para OAuth2-Proxy
resource "aws_lb_target_group" "oauth2_proxy" {
  name        = "retrogame-oauth2-tg"
  port        = 4180
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/ping"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = {
    Name        = "retrogame-oauth2-tg"
    Service     = "oauth2-proxy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Target Group para Frontend
resource "aws_lb_target_group" "frontend" {
  name        = "retrogame-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = {
    Name        = "retrogame-frontend-tg"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }
}

# Target Group para Grafana
resource "aws_lb_target_group" "grafana" {
  name        = "retrogame-grafana-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,302"
    path                = "/grafana/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name        = "retrogame-grafana-tg"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }
}

# Target Group para Prometheus
resource "aws_lb_target_group" "prometheus" {
  name        = "retrogame-prometheus-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/prometheus/-/healthy"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name        = "retrogame-prometheus-tg"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }
}

# Target Group para AlertManager
resource "aws_lb_target_group" "alertmanager" {
  name        = "retrogame-alertmanager-tg"
  port        = 9093
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/alertmanager/-/healthy"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name        = "retrogame-alertmanager-tg"
    Environment = var.environment
    Project     = "retrogame"
    ManagedBy   = "terraform"
  }
}

# ============================================================================
# Listeners
# ============================================================================

# HTTP Listener - Redirigir a HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  # Default action: Frontend (sin autenticación)
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  depends_on = [aws_acm_certificate_validation.main]
}

# ============================================================================
# Listener Rules - Path-based routing con GitHub OAuth
# ============================================================================

# Rule para OAuth2-proxy callback (máxima prioridad)
resource "aws_lb_listener_rule" "oauth2_callback" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.oauth2_proxy.arn
  }

  condition {
    path_pattern {
      values = ["/oauth2/*"]
    }
  }
}

# Rule para Grafana (con GitHub OAuth via oauth2-proxy)
resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  # Primero: Verificar autenticación con oauth2-proxy
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.oauth2_proxy.arn
  }

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }

  # oauth2-proxy verificará la cookie y redirigirá a GitHub si es necesario
  # Después de la auth, oauth2-proxy hace proxy inverso a Grafana
}

# Rule para Prometheus (con GitHub OAuth via oauth2-proxy)
resource "aws_lb_listener_rule" "prometheus" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.oauth2_proxy.arn
  }

  condition {
    path_pattern {
      values = ["/prometheus", "/prometheus/*"]
    }
  }
}

# Rule para AlertManager (con GitHub OAuth via oauth2-proxy)
resource "aws_lb_listener_rule" "alertmanager" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.oauth2_proxy.arn
  }

  condition {
    path_pattern {
      values = ["/alertmanager", "/alertmanager/*"]
    }
  }
}

# ============================================================================
# Target Group Attachments (se registrarán con los IPs de los pods)
# ============================================================================

# Los attachments se harán con un null_resource que obtenga los IPs de los pods
# después de que los servicios estén corriendo

resource "null_resource" "register_targets" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "⏳ Esperando a que los pods estén listos..."
      sleep 30
      
      # Obtener IPs de los pods de Frontend
      FRONTEND_IPS=$(kubectl get pods -n retrogame -l app=frontend -o jsonpath='{.items[*].status.podIP}')
      for IP in $FRONTEND_IPS; do
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.frontend.arn} \
          --targets Id=$IP,Port=80 \
          --region ${var.aws_region} || true
      done
      
      # Obtener IPs de OAuth2-Proxy
      OAUTH2_IPS=$(kubectl get pods -n monitoring -l app=oauth2-proxy -o jsonpath='{.items[*].status.podIP}')
      for IP in $OAUTH2_IPS; do
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.oauth2_proxy.arn} \
          --targets Id=$IP,Port=4180 \
          --region ${var.aws_region} || true
      done
      
      # Obtener IPs de Grafana
      GRAFANA_IPS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].status.podIP}')
      for IP in $GRAFANA_IPS; do
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.grafana.arn} \
          --targets Id=$IP,Port=80 \
          --region ${var.aws_region} || true
      done
      
      # Obtener IPs de Prometheus
      PROMETHEUS_IPS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[*].status.podIP}')
      for IP in $PROMETHEUS_IPS; do
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.prometheus.arn} \
          --targets Id=$IP,Port=9090 \
          --region ${var.aws_region} || true
      done
      
      # Obtener IPs de AlertManager
      ALERTMANAGER_IPS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager -o jsonpath='{.items[*].status.podIP}')
      for IP in $ALERTMANAGER_IPS; do
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.alertmanager.arn} \
          --targets Id=$IP,Port=9093 \
          --region ${var.aws_region} || true
      done
      
      echo "✅ Targets registrados en ALB"
    EOT
  }

  depends_on = [
    aws_lb_target_group.frontend,
    aws_lb_target_group.grafana,
    aws_lb_target_group.prometheus,
    aws_lb_target_group.alertmanager,
    kubernetes_deployment.frontend,
    helm_release.kube_prometheus_stack
  ]
}
