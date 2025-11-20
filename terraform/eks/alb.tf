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
  name        = "retrogame-frontend-v2-tg"
  port        = 8081
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

  lifecycle {
    create_before_destroy = true
  }

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
  port        = 3000
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

  lifecycle {
    create_before_destroy = true
  }

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

# Target Group para Ingress NGINX (maneja OAuth internamente)
resource "aws_lb_target_group" "ingress_nginx" {
  name        = "retrogame-ingress-nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,404"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name        = "retrogame-ingress-nginx-tg"
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

  # Default action: Todo pasa por Ingress NGINX
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_nginx.arn
  }

  depends_on = [aws_acm_certificate_validation.main]
}

# ============================================================================
# Listener Rules - Routing a Ingress NGINX para OAuth
# ============================================================================

# Rule para enviar todo el tráfico de monitoring a Ingress NGINX
# Ingress NGINX manejará OAuth2-Proxy internamente - Paths con trailing slash y subpaths
resource "aws_lb_listener_rule" "monitoring_ingress" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_nginx.arn
  }

  condition {
    path_pattern {
      values = ["/grafana/*", "/prometheus/*", "/alertmanager/*", "/oauth2/*"]
    }
  }
}

# Rule para redirect de paths sin trailing slash a paths con trailing slash
resource "aws_lb_listener_rule" "monitoring_ingress_redirect" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 9

  action {
    type = "redirect"
    redirect {
      status_code = "HTTP_301"
      path        = "/#{path}/"
    }
  }

  condition {
    path_pattern {
      values = ["/grafana", "/prometheus", "/alertmanager"]
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
      echo "⏳ Esperando a que ALB y listeners estén completamente configurados..."
      sleep 120
      
      # Configurar AWS CLI
      export AWS_PROFILE=retrogamecloud-terraform
      export AWS_REGION=eu-west-1
      
      # Obtener IPs de Ingress NGINX Controller
      INGRESS_IPS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[*].status.podIP}')
      for IP in $INGRESS_IPS; do
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.ingress_nginx.arn} \
          --targets Id=$IP,Port=80 \
          --profile retrogamecloud-terraform \
          --region eu-west-1 || true
      done
      
      echo "✅ Targets de Ingress NGINX registrados en ALB"
    EOT
  }

  depends_on = [
    aws_lb.main,
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_lb_target_group.ingress_nginx,
    aws_lb_listener_rule.monitoring_ingress,
    helm_release.kube_prometheus_stack,
    helm_release.ingress_nginx
  ]
}
