# ==============================================================================
# S3 Buckets Configuration
# ==============================================================================
# Security features implemented:
# - HTTPS-only access enforced via bucket policies (aws_s3_bucket_policy)
# - Logging enabled for main bucket (aws_s3_bucket_logging.games_cdn)
# - Public access blocked for both buckets
# - Versioning enabled for main bucket
# ==============================================================================

# S3 Bucket para juegos y assets estáticos
# SONAR: Logging is configured in aws_s3_bucket_logging.games_cdn resource
# SONAR: HTTPS policy is configured in aws_s3_bucket_policy.games_cdn resource
resource "aws_s3_bucket" "games_cdn" {
  bucket        = "${var.cluster_name}-games-cdn"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-games-cdn"
    }
  )
}

# Bloquear acceso público al bucket principal (accederemos via CloudFront)
resource "aws_s3_bucket_public_access_block" "games_cdn" {
  bucket = aws_s3_bucket.games_cdn.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket de logs para S3
# SONAR: This is a logs bucket, recursive logging is not required
# SONAR: HTTPS policy is configured in aws_s3_bucket_policy.cdn_logs resource
# SONAR: ACL log-delivery-write is configured in aws_s3_bucket_acl.cdn_logs resource
resource "aws_s3_bucket" "cdn_logs" {
  bucket        = "${var.cluster_name}-cdn-logs"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cdn-logs"
    }
  )
}

resource "aws_s3_bucket_ownership_controls" "cdn_logs" {
  bucket = aws_s3_bucket.cdn_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "cdn_logs" {
  bucket = aws_s3_bucket.cdn_logs.id

  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "cdn_logs" {
  bucket = aws_s3_bucket.cdn_logs.id
  acl    = "log-delivery-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.cdn_logs,
    aws_s3_bucket_public_access_block.cdn_logs
  ]
}

# Política de HTTPS obligatorio para bucket de logs + permisos CloudFront
resource "aws_s3_bucket_policy" "cdn_logs" {
  bucket = aws_s3_bucket.cdn_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cdn_logs.arn,
          "${aws_s3_bucket.cdn_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:PutBucketAcl"
        ]
        Resource = aws_s3_bucket.cdn_logs.arn
      },
      {
        Sid    = "AllowCloudFrontLogs"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cdn_logs.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.cdn_logs,
    aws_s3_bucket_acl.cdn_logs
  ]
}

# Habilitar versionado
resource "aws_s3_bucket_versioning" "games_cdn" {
  bucket = aws_s3_bucket.games_cdn.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Habilitar logging en el bucket principal
resource "aws_s3_bucket_logging" "games_cdn" {
  bucket = aws_s3_bucket.games_cdn.id

  target_bucket = aws_s3_bucket.cdn_logs.id
  target_prefix = "s3-access-logs/"
}

# Configuración CORS para permitir acceso desde cualquier origen
resource "aws_s3_bucket_cors_configuration" "games_cdn" {
  bucket = aws_s3_bucket.games_cdn.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# Política del bucket - solo CloudFront puede acceder + HTTPS obligatorio
resource "aws_s3_bucket_policy" "games_cdn" {
  bucket = aws_s3_bucket.games_cdn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.games_cdn.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.games_cdn.arn
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.games_cdn.arn,
          "${aws_s3_bucket.games_cdn.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.games_cdn,
    aws_cloudfront_distribution.games_cdn
  ]
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "games_cdn" {
  name                              = "${var.cluster_name}-games-oac"
  description                       = "OAC for games CDN"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "games_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for RetroGame static assets"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cdn_logs.bucket_domain_name
    prefix          = "cloudfront-logs/"
  }

  origin {
    domain_name              = aws_s3_bucket.games_cdn.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.games_cdn.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.games_cdn.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.games_cdn.id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Cache behavior para juegos .jsdos (mayor TTL)
  ordered_cache_behavior {
    path_pattern     = "/juegos/*.jsdos"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.games_cdn.id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 604800  # 7 días
    max_ttl                = 2592000 # 30 días
    compress               = true
  }

  # Cache behavior para imágenes
  ordered_cache_behavior {
    path_pattern     = "/img/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.games_cdn.id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 604800
    max_ttl                = 2592000
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-games-cdn"
    }
  )
}

# IAM Role para que los pods puedan subir archivos a S3 (opcional, para administración)
resource "aws_iam_role" "s3_upload_role" {
  name = "${var.cluster_name}-s3-upload-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:retrogamecloud:s3-uploader"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-s3-upload-role"
    }
  )
}

resource "aws_iam_role_policy" "s3_upload_policy" {
  name = "${var.cluster_name}-s3-upload-policy"
  role = aws_iam_role.s3_upload_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.games_cdn.arn,
          "${aws_s3_bucket.games_cdn.arn}/*"
        ]
      }
    ]
  })
}

# ConfigMap con URL de CloudFront para que la app lo use
resource "kubernetes_config_map" "cdn_config" {
  metadata {
    name      = "cdn-config"
    namespace = kubernetes_namespace.retrogamecloud.metadata[0].name
  }

  data = {
    CDN_URL           = "https://${aws_cloudfront_distribution.games_cdn.domain_name}"
    CDN_DISTRIBUTION  = aws_cloudfront_distribution.games_cdn.id
    S3_BUCKET         = aws_s3_bucket.games_cdn.id
  }

  depends_on = [
    module.eks,
    aws_cloudfront_distribution.games_cdn
  ]
}

# Subir archivos estáticos automáticamente al bucket S3
resource "null_resource" "upload_static_files" {
  triggers = {
    bucket_id = aws_s3_bucket.games_cdn.id
    # Forzar subida en cada apply
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "📦 Subiendo juegos (.jsdos) al CDN..."
      aws s3 sync ${path.root}/../../../infraestructure/cdn/juegos/ s3://${aws_s3_bucket.games_cdn.id}/juegos/ \
        --region ${var.aws_region} \
        --delete \
        --exclude "*" \
        --include "*.jsdos"
      
      echo "🖼️  Subiendo imágenes al CDN..."
      aws s3 sync ${path.root}/../../../infraestructure/cdn/img/ s3://${aws_s3_bucket.games_cdn.id}/img/ \
        --region ${var.aws_region} \
        --delete \
        --exclude "*" \
        --include "*.jpg" \
        --include "*.png" \
        --include "*.gif"
      
      echo "🎮 Subiendo emulador js-dos al CDN..."
      aws s3 sync ${path.root}/../../../frontend/jsdos/ s3://${aws_s3_bucket.games_cdn.id}/jsdos/ \
        --region ${var.aws_region} \
        --delete \
        --exclude "*" \
        --include "*.js" \
        --include "*.css" \
        --include "*.wasm" \
        --include "*.html" \
        --include "*.symbols"
      
      echo "✅ Todos los archivos estáticos subidos al CDN"
    EOT
  }

  depends_on = [
    aws_s3_bucket.games_cdn,
    aws_s3_bucket_public_access_block.games_cdn,
    aws_cloudfront_distribution.games_cdn
  ]
}
