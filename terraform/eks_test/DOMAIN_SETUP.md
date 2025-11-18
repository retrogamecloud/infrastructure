# 🌐 Setup de Dominio: retrogamehub.games

## ✅ Estado Actual

- **Dominio**: `retrogamehub.games` ✅ COMPRADO
- **Registrador**: (indicar dónde lo compraste: Route53, Namecheap, etc.)
- **Fecha de compra**: 17 Nov 2025
- **Expiración**: 17 Nov 2026

---

## 📋 Checklist de Configuración

### Paso 1: Crear Hosted Zone en Route53 (15 min)

```bash
# Opción A: Via AWS Console
# 1. Ir a: https://console.aws.amazon.com/route53/v2/hostedzones
# 2. Click "Create hosted zone"
# 3. Domain name: retrogamehub.games
# 4. Type: Public hosted zone
# 5. Click "Create hosted zone"

# Opción B: Via Terraform (RECOMENDADO)
# Ver archivo: route53.tf (crear nuevo)
```

**Resultado esperado:**
- Hosted zone creada
- 4 nameservers asignados (ej: ns-xxx.awsdns-xx.com)
- **IMPORTANTE**: Anotar los nameservers

---

### Paso 2: Actualizar Nameservers en Registrador (5-10 min)

**Si compraste en Route53:**
- ✅ Ya está configurado automáticamente
- Skip este paso

**Si compraste en Namecheap/GoDaddy/otro:**
1. Login al panel del registrador
2. Ir a "Domain Management" o "DNS Settings"
3. Cambiar nameservers a los de Route53:
   ```
   ns-xxxx.awsdns-xx.com
   ns-xxxx.awsdns-xx.net
   ns-xxxx.awsdns-xx.org
   ns-xxxx.awsdns-xx.co.uk
   ```
4. Guardar cambios

⚠️ **Propagación DNS**: 24-48 horas (pero generalmente 2-4 horas)

**Verificar propagación:**
```bash
# Comprobar nameservers actuales
dig NS retrogamehub.games

# Comprobar desde diferentes servidores DNS
dig @8.8.8.8 retrogamehub.games
dig @1.1.1.1 retrogamehub.games
```

---

### Paso 3: Solicitar Certificados SSL en ACM (10 min)

**Certificado para CloudFront (us-east-1):**
```bash
# Cambiar región a us-east-1
aws acm request-certificate \
  --domain-name retrogamehub.games \
  --subject-alternative-names "*.retrogamehub.games" \
  --validation-method DNS \
  --region us-east-1

# Anotar el ARN del certificado
# arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID
```

**Certificado para Load Balancer (eu-west-1):**
```bash
# Región actual (donde está el EKS)
aws acm request-certificate \
  --domain-name retrogamehub.games \
  --subject-alternative-names "*.retrogamehub.games" \
  --validation-method DNS \
  --region eu-west-1

# Anotar el ARN del certificado
```

**Validación DNS (automática con Route53):**
1. Ir a ACM Console en cada región
2. Los records CNAME de validación se crean automáticamente en Route53
3. Esperar 5-30 minutos hasta que el status sea "Issued"

**Verificar certificados:**
```bash
# us-east-1
aws acm list-certificates --region us-east-1

# eu-west-1
aws acm list-certificates --region eu-west-1
```

---

### Paso 4: Configurar DNS Records en Route53 (15 min)

**Records a crear:**

```hcl
# A Record - Apex domain → CloudFront
retrogamehub.games
  Type: A - IPv4 address
  Alias: Yes
  Alias target: CloudFront distribution (dxxxxxxxxxxxxxx.cloudfront.net)

# CNAME Record - www → CloudFront
www.retrogamehub.games
  Type: CNAME
  Value: dxxxxxxxxxxxxxx.cloudfront.net

# CNAME Record - cdn → CloudFront  
cdn.retrogamehub.games
  Type: CNAME
  Value: dxxxxxxxxxxxxxx.cloudfront.net

# A Record - api → Kong Load Balancer
api.retrogamehub.games
  Type: A - IPv4 address
  Alias: Yes
  Alias target: Kong NLB (axxxxxx.elb.eu-west-1.amazonaws.com)

# CNAME Record - grafana → Kong (internal)
# grafana.retrogamehub.games
#   Type: CNAME
#   Value: Kong NLB
# (Configurar después con Grafana)
```

**Via Terraform (recomendado):**
Ver archivo `route53.tf` que crearemos

---

### Paso 5: Actualizar CloudFront Distribution (10 min)

```bash
# 1. Ir a CloudFront Console
# 2. Seleccionar tu distribution (dxxxxxxxxxxxxxx.cloudfront.net)
# 3. Edit settings:
#    - Alternate domain names (CNAMEs):
#      * retrogamehub.games
#      * www.retrogamehub.games
#      * cdn.retrogamehub.games
#    - Custom SSL certificate:
#      * Seleccionar el certificado de us-east-1
# 4. Save changes
# 5. Wait for deployment (~5-10 min)
```

**Verificar:**
```bash
curl -I https://retrogamehub.games
curl -I https://www.retrogamehub.games
curl -I https://cdn.retrogamehub.games
```

---

### Paso 6: Configurar Kong con SSL/HTTPS (15 min)

**Opción A: SSL Termination en Load Balancer (Recomendado)**

Modificar el Service de Kong para usar certificado ACM:

```yaml
# Via annotations en el Service
apiVersion: v1
kind: Service
metadata:
  name: kong
  namespace: retrogame
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:eu-west-1:ACCOUNT_ID:certificate/CERT_ID"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    targetPort: 8000
  - name: https
    port: 443
    targetPort: 8000
```

**Opción B: Via Terraform (más limpio):**
Ver actualización en `kubernetes.tf`

---

### Paso 7: Actualizar Frontend URLs (5 min)

**Actualizar en Terraform:**

```hcl
# En kubernetes.tf, buscar kubernetes_config_map_v1_data.frontend_urls
# Y actualizar LB_URL y CDN_URL

locals {
  kong_lb_url  = "https://api.retrogamehub.games"
  cdn_url      = "https://cdn.retrogamehub.games"
}

resource "kubernetes_config_map_v1_data" "frontend_urls" {
  # ... existing config ...
  
  data = {
    "replace-urls.sh" = <<-EOT
      #!/bin/sh
      set -e
      
      LB_URL="${local.kong_lb_url}"
      CDN_URL="${local.cdn_url}"
      
      # ... rest of script ...
    EOT
  }
}
```

---

### Paso 8: Forzar Redirección HTTP → HTTPS (5 min)

**En Kong (via plugin):**
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: https-redirect
  namespace: retrogame
config:
  https_redirect_status_code: 301
plugin: request-termination
---
# Aplicar a las rutas
```

**En CloudFront (via Viewer Protocol Policy):**
- Settings → Behavior → Viewer Protocol Policy: "Redirect HTTP to HTTPS"

---

## 🧪 Testing Completo

### Test 1: DNS Propagation
```bash
# Nameservers correctos
dig NS retrogamehub.games

# A record para apex
dig A retrogamehub.games

# A record para api
dig A api.retrogamehub.games

# CNAME para www
dig CNAME www.retrogamehub.games
```

### Test 2: SSL Certificates
```bash
# CloudFront (apex, www, cdn)
openssl s_client -connect retrogamehub.games:443 -servername retrogamehub.games < /dev/null | grep "Verify return code"

# Load Balancer (api)
openssl s_client -connect api.retrogamehub.games:443 -servername api.retrogamehub.games < /dev/null | grep "Verify return code"
```

### Test 3: HTTP → HTTPS Redirect
```bash
# Debe redirigir a HTTPS
curl -I http://retrogamehub.games
curl -I http://api.retrogamehub.games
```

### Test 4: Frontend Functional
```bash
# Debe cargar correctamente
curl -I https://retrogamehub.games
curl -I https://www.retrogamehub.games
curl -I https://cdn.retrogamehub.games/img/logo.png
```

### Test 5: Backend API
```bash
# Health check
curl https://api.retrogamehub.games/api/health

# Auth endpoint
curl -X POST https://api.retrogamehub.games/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@test.com","password":"Test123!"}'
```

### Test 6: Browser Testing
- Abrir en navegador: https://retrogamehub.games
- Verificar candado SSL verde
- Verificar que no hay warnings de contenido mixto (HTTP/HTTPS)
- Test completo: registro, login, jugar, ver rankings

---

## 🔧 Troubleshooting

### DNS no resuelve
```bash
# Ver propagación global
https://www.whatsmydns.net/#A/retrogamehub.games

# Flush local DNS cache
# Linux
sudo systemd-resolve --flush-caches

# Mac
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Windows
ipconfig /flushdns
```

### Certificado SSL no válido
- Verificar que el certificado está en "Issued" status en ACM
- Verificar que CloudFront usa el certificado de us-east-1
- Verificar que Load Balancer usa el certificado de eu-west-1
- Esperar 5-10 min después de configurar certificado en CloudFront

### Contenido mixto (HTTP/HTTPS)
```bash
# Ver requests del frontend
curl https://retrogamehub.games | grep -i "http://"

# Debe usar HTTPS para todo:
# - API calls → https://api.retrogamehub.games
# - Assets → https://cdn.retrogamehub.games
```

### Load Balancer no responde en HTTPS
- Verificar annotations del Service de Kong
- Verificar listener 443 en Load Balancer (AWS Console)
- Verificar Security Groups permiten puerto 443

---

## 📊 Costos

| Servicio | Costo |
|----------|-------|
| Dominio .games | ~$20/año |
| Route53 Hosted Zone | $0.50/mes |
| Route53 Queries | ~$0.40/mes (primeros 1M gratis) |
| ACM Certificates | **GRATIS** |
| **TOTAL ADICIONAL** | **~$1-2/mes** |

---

## ✅ Checklist Final

- [ ] Hosted zone creada en Route53
- [ ] Nameservers actualizados en registrador
- [ ] DNS propagado (verificado con dig)
- [ ] Certificado ACM para CloudFront (us-east-1) - Issued
- [ ] Certificado ACM para Load Balancer (eu-west-1) - Issued
- [ ] DNS records configurados (A, CNAME)
- [ ] CloudFront con custom domain y SSL
- [ ] Kong Load Balancer con SSL en puerto 443
- [ ] Frontend URLs actualizadas (https://api, https://cdn)
- [ ] HTTP → HTTPS redirect funcionando
- [ ] Testing completo pasado
- [ ] Browser testing OK (candado verde)

---

## 🎯 Próximo Paso

Una vez completado el setup del dominio:
- Actualizar ROADMAP.md ✅
- Proceder con FASE 1: Prometheus + Grafana
- Usar `grafana.retrogamehub.games` para acceso a dashboards

---

## 📚 Referencias

- [AWS Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [AWS ACM Documentation](https://docs.aws.amazon.com/acm/)
- [CloudFront Custom Domains](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CNAMEs.html)
- [Kong SSL Termination](https://docs.konghq.com/gateway/latest/production/networking/ssl-termination/)
