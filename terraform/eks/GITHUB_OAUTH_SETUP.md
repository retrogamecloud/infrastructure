# GitHub OAuth Setup Guide

## 📋 Resumen

Esta guía explica cómo configurar GitHub OAuth para proteger Grafana, Prometheus y AlertManager usando **oauth2-proxy**.

**Arquitectura:**
```
Internet → ALB (HTTPS)
         ├─ / → Frontend (público)
         └─ /grafana, /prometheus, /alertmanager
            → OAuth2-Proxy (GitHub authentication)
               → Backend Services
```

**Ventajas sobre Cognito:**
- ✅ Sin costos adicionales (GitHub OAuth es gratis)
- ✅ No necesitas gestionar usuarios
- ✅ Los desarrolladores ya tienen cuenta de GitHub
- ✅ Puedes restringir por organización/equipo de GitHub
- ✅ Mejor UX para equipos de desarrollo

---

## 🚀 Implementación Paso a Paso

### Paso 1: Crear GitHub OAuth App

1. Ve a **GitHub Settings** → **Developer settings** → **OAuth Apps**:
   - URL directa: https://github.com/settings/developers

2. Click en **"New OAuth App"**

3. Completa el formulario:
   ```
   Application name: Retrogame Monitoring
   Homepage URL: https://retrogamehub.games
   Authorization callback URL: https://retrogamehub.games/oauth2/callback
   ```

4. Click en **"Register application"**

5. **Guarda los valores:**
   - **Client ID**: Lo verás directamente (ejemplo: `Iv1.a1b2c3d4e5f6g7h8`)
   - **Client Secret**: Click en "Generate a new client secret" y cópialo inmediatamente
   
   ⚠️ **IMPORTANTE**: El Client Secret solo se muestra una vez. Guárdalo en un lugar seguro.

---

### Paso 2: Configurar Variables de Terraform

**Opción A: Variables de entorno (recomendado para producción)**
```bash
export TF_VAR_github_oauth_client_id="Iv1.a1b2c3d4e5f6g7h8"
export TF_VAR_github_oauth_client_secret="tu_client_secret_aqui"
```

**Opción B: Archivo terraform.tfvars (NO commitear a git)**
```bash
cd /mnt/c/proyecto_final/infraestructure/terraform/eks_test

# Crear archivo terraform.tfvars
cat > terraform.tfvars <<EOF
github_oauth_client_id     = "Iv1.a1b2c3d4e5f6g7h8"
github_oauth_client_secret = "tu_client_secret_aqui"
EOF

# ⚠️ Asegúrate de que esté en .gitignore
echo "terraform.tfvars" >> .gitignore
```

---

### Paso 3: Aplicar la Infraestructura

```bash
cd /mnt/c/proyecto_final/infraestructure/terraform/eks_test

# Revisar cambios
terraform plan

# Aplicar (esto creará ALB, Route53, oauth2-proxy, etc.)
terraform apply

# Obtener nameservers para Namecheap
terraform output route53_nameservers
```

**Recursos que se crearán:**
- Application Load Balancer + Security Group
- 5 Target Groups (frontend, oauth2-proxy, grafana, prometheus, alertmanager)
- Route53 Zone + ACM Certificate
- OAuth2-Proxy Deployment (2 réplicas)
- Kubernetes Secret con credenciales de GitHub
- ALB Listener Rules con path-based routing

---

### Paso 4: Configurar Nameservers en Namecheap

1. Copia los nameservers del output de Terraform:
   ```bash
   terraform output route53_nameservers
   ```
   
   Ejemplo de salida:
   ```
   [
     "ns-1234.awsdns-56.org",
     "ns-789.awsdns-12.co.uk",
     "ns-345.awsdns-67.com",
     "ns-890.awsdns-34.net"
   ]
   ```

2. Ve a **Namecheap** → **Domain List** → **Manage** (tu dominio)

3. En **NAMESERVERS**, selecciona **"Custom DNS"**

4. Añade los 4 nameservers de AWS:
   ```
   ns-1234.awsdns-56.org
   ns-789.awsdns-12.co.uk
   ns-345.awsdns-67.com
   ns-890.awsdns-34.net
   ```

5. Click en **✓ Save**

6. **Espera a la propagación DNS** (15 minutos - 48 horas, típicamente < 1 hora)

**Verificar propagación:**
```bash
# Comprobar que el dominio apunta al ALB
dig retrogamehub.games

# Comprobar certificado SSL
curl -I https://retrogamehub.games
```

---

### Paso 5: Probar el Acceso

Una vez que el DNS se haya propagado y el certificado SSL esté validado:

#### Frontend (público, sin autenticación)
```bash
curl -I https://retrogamehub.games
# Expected: 200 OK
```

#### Grafana (requiere GitHub login)
```bash
# En el navegador, visita:
https://retrogamehub.games/grafana
```

**Flujo esperado:**
1. Redirección a `https://retrogamehub.games/oauth2/start?rd=/grafana`
2. Redirección a GitHub OAuth
3. Login con tu cuenta de GitHub
4. Autorizar la aplicación "Retrogame Monitoring"
5. Redirección de vuelta a Grafana
6. ✅ Acceso concedido

#### Prometheus
```bash
https://retrogamehub.games/prometheus
```

#### AlertManager
```bash
https://retrogamehub.games/alertmanager
```

---

## 🔒 Control de Acceso Avanzado

### Restringir por Organización de GitHub

Edita `oauth2_proxy.tf` y descomenta:

```hcl
# github_org = "your-org-name"
```

Cambia a:
```hcl
github_org = "retrogamecloud"  # Tu organización
```

**Efecto:** Solo usuarios que pertenezcan a la organización `retrogamecloud` podrán acceder.

---

### Restringir por Equipo de GitHub

```hcl
github_org = "retrogamecloud"
github_team = "monitoring-admins"  # Nombre del equipo
```

**Efecto:** Solo usuarios del equipo `monitoring-admins` en `retrogamecloud` podrán acceder.

---

### Restringir por Lista de Usuarios

```hcl
github_users = [ "usuario1", "usuario2", "usuario3" ]
```

**Efecto:** Solo los usuarios especificados podrán acceder.

---

## 🛠️ Troubleshooting

### 1. Error: "Invalid redirect_uri"

**Causa:** El callback URL en GitHub no coincide con el configurado.

**Solución:**
```bash
# Verifica el callback URL en GitHub:
# https://github.com/settings/developers
# Debe ser exactamente: https://retrogamehub.games/oauth2/callback

# Verifica en oauth2-proxy:
terraform show | grep redirect-url
```

---

### 2. Error: "502 Bad Gateway" en /grafana

**Causa:** oauth2-proxy no puede conectar con el servicio backend.

**Diagnóstico:**
```bash
# Verificar pods de oauth2-proxy
kubectl get pods -n monitoring -l app=oauth2-proxy

# Ver logs
kubectl logs -n monitoring -l app=oauth2-proxy --tail=50

# Verificar servicios backend
kubectl get svc -n monitoring
```

**Solución común:**
```bash
# Verificar que los servicios existen
kubectl get svc -n monitoring kube-prometheus-stack-grafana
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get svc -n monitoring kube-prometheus-stack-alertmanager

# Si no existen, los nombres pueden ser diferentes
kubectl get svc -n monitoring | grep -E "grafana|prometheus|alertmanager"
```

---

### 3. Error: "Cookie mismatch" o sesiones no persisten

**Causa:** Problemas con el cookie secret o configuración de cookies.

**Solución:**
```bash
# Regenerar cookie secret
terraform taint random_password.oauth2_proxy_cookie_secret
terraform apply

# Reiniciar oauth2-proxy
kubectl rollout restart deployment/oauth2-proxy -n monitoring
```

---

### 4. Certificado SSL no válido

**Causa:** La validación DNS aún no se completó.

**Verificar estado:**
```bash
terraform output ssl_certificate_status

# Comprobar en AWS Console
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw ssl_certificate_arn) \
  --region eu-west-1
```

**Esperar hasta que el estado sea `ISSUED` (puede tomar 5-30 minutos).**

---

### 5. Error: "Access denied" después de login

**Causa:** Las restricciones de acceso son demasiado estrictas.

**Verificar configuración:**
```bash
kubectl get cm -n monitoring oauth2-proxy -o yaml
```

**Solución temporal (permitir todos los usuarios de GitHub):**
```hcl
# En oauth2_proxy.tf, asegúrate de que:
email_domains = [ "*" ]

# Y comenta las restricciones:
# github_org = ""
# github_team = ""
# github_users = []
```

---

## 📊 Verificación del Sistema

### Comprobar Pods
```bash
# OAuth2-Proxy
kubectl get pods -n monitoring -l app=oauth2-proxy
# Expected: 2/2 Running

# Monitoring stack
kubectl get pods -n monitoring
```

### Comprobar Target Groups
```bash
# Ver estado de targets en ALB
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw oauth2_proxy_target_group_arn) \
  --region eu-west-1

# Debería mostrar targets "healthy"
```

### Comprobar Logs de OAuth2-Proxy
```bash
# Ver últimas 100 líneas
kubectl logs -n monitoring -l app=oauth2-proxy --tail=100 -f

# Buscar errores
kubectl logs -n monitoring -l app=oauth2-proxy | grep -i error
```

### Test de Conectividad
```bash
# Desde un pod dentro del cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh

# Dentro del pod:
curl http://oauth2-proxy.monitoring.svc.cluster.local:4180/ping
# Expected: OK

curl -I http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80
# Expected: 200 or 302
```

---

## 💰 Costos Estimados

| Servicio | Costo Mensual (aprox.) |
|----------|------------------------|
| Route53 Hosted Zone | $0.50 |
| Route53 Queries | ~$0.40 (1M queries) |
| ALB | ~$16.20 (744h × $0.0225/h) |
| ACM Certificate | **$0.00** (gratis) |
| oauth2-proxy pods | Dentro del cluster (sin costo adicional) |
| **Total** | **~$17.10/mes** |

**Ahorro vs Cognito:**
- Cognito User Pool: $0.00 (primeros 50k MAU)
- Pero con Cognito aún necesitas ALB: $16.20
- **Ahorro total:** Similar en costo, pero GitHub OAuth es más fácil de usar

---

## 🔐 Mejores Prácticas de Seguridad

### 1. Rotar Client Secret Periódicamente
```bash
# En GitHub:
# 1. Settings → Developer settings → OAuth Apps
# 2. Click en tu app
# 3. "Generate a new client secret"
# 4. Actualizar en Terraform:

export TF_VAR_github_oauth_client_secret="nuevo_secret"
terraform apply

# Reiniciar oauth2-proxy
kubectl rollout restart deployment/oauth2-proxy -n monitoring
```

### 2. Limitar Acceso por Organización
```hcl
# Siempre especifica tu organización:
github_org = "retrogamecloud"
```

### 3. Habilitar Audit Logs
```hcl
# En oauth2_proxy.cfg:
request_logging = true
auth_logging = true

# Ver logs:
kubectl logs -n monitoring -l app=oauth2-proxy | grep "authenticated"
```

### 4. Revicar Sesiones Activas
```bash
# Las sesiones OAuth2-proxy son cookies locales
# Expiran automáticamente después de 7 días (cookie_expire = "168h")
# Para forzar logout, el usuario debe borrar cookies del navegador
```

### 5. Considerar IP Whitelist (opcional)
```hcl
# Si quieres restringir por IP además de GitHub:
# En alb.tf, añade rules al security group:

ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["1.2.3.4/32"]  # Solo tu IP
  description = "Allow HTTPS from office IP"
}
```

---

## 🔗 URLs Importantes

| Servicio | URL |
|----------|-----|
| Frontend (público) | https://retrogamehub.games |
| Grafana | https://retrogamehub.games/grafana |
| Prometheus | https://retrogamehub.games/prometheus |
| AlertManager | https://retrogamehub.games/alertmanager |
| OAuth2 Callback | https://retrogamehub.games/oauth2/callback |

---

## 📚 Referencias

- **oauth2-proxy Documentation**: https://oauth2-proxy.github.io/oauth2-proxy/
- **GitHub OAuth Apps**: https://docs.github.com/en/developers/apps/building-oauth-apps
- **AWS ALB Target Groups**: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

## ✅ Checklist Final

- [ ] GitHub OAuth App creada
- [ ] Client ID y Secret guardados de forma segura
- [ ] Variables de Terraform configuradas
- [ ] `terraform apply` ejecutado exitosamente
- [ ] Nameservers configurados en Namecheap
- [ ] DNS propagado (verificado con `dig`)
- [ ] Certificado SSL validado (estado `ISSUED`)
- [ ] Frontend accesible sin autenticación
- [ ] Grafana requiere login de GitHub
- [ ] Prometheus requiere login de GitHub
- [ ] AlertManager requiere login de GitHub
- [ ] Restricciones de acceso configuradas (org/team/users)
- [ ] Logs de oauth2-proxy funcionando correctamente

---

**¿Problemas?** Revisa la sección [Troubleshooting](#-troubleshooting) o abre un issue en el repositorio.
