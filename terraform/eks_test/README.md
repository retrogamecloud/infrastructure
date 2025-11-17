# RetroGameCloud - EKS Deployment con Terraform

Este directorio contiene la infraestructura como código (IaC) para desplegar RetroGameCloud en AWS usando EKS (Elastic Kubernetes Service).

## Arquitectura

- **VPC**: Red privada virtual con subnets públicas en 3 Availability Zones
- **EKS Cluster**: Kubernetes v1.31 con **AWS Fargate** (serverless, sin EC2)
- **RDS PostgreSQL**: Base de datos gestionada (PostgreSQL 15.15)
- **S3 + CloudFront**: CDN para archivos estáticos (juegos .jsdos, imágenes)
- **Load Balancer**: Network Load Balancer (NLB) para Kong API Gateway
- **Security Groups**: Aislamiento de red entre componentes

### ¿Por qué Fargate?

✅ **Sin gestión de nodos EC2** - AWS maneja todo el compute
✅ **Sin NAT Gateway** - Ahorro de $32/mes
✅ **Pago por uso** - Solo pagas por vCPU/memoria consumida
✅ **Autoscaling automático** - Escala pods sin gestionar capacidad
✅ **Despliegue más rápido** - Pods inician en 30-60 segundos

## Componentes

### Infraestructura AWS
- `provider.tf`: Configuración de providers (AWS, Kubernetes, Helm)
- `variables.tf`: Variables configurables
- `eks.tf`: Cluster EKS, VPC, **Fargate Profiles**, Security Groups
- `rds.tf`: RDS PostgreSQL con seed data
- `s3-cdn.tf`: S3 Bucket y CloudFront Distribution para assets
- `outputs.tf`: Outputs útiles post-despliegue

### Aplicaciones Kubernetes
- `kubernetes.tf`: Deployments, Services, ConfigMaps, Secrets
  - Backend (2 réplicas) - 0.5 vCPU, 1GB RAM por pod
  - Frontend (2 réplicas) - 0.25 vCPU, 512MB RAM por pod
  - Kong API Gateway (1 réplica) - 0.5 vCPU, 1GB RAM

### Fargate Profiles Configurados
- `kube-system`: CoreDNS y componentes del sistema
- `default`: Namespace default
- `retrogame`: Aplicaciones de RetroGameCloud

## Prerrequisitos

1. **AWS CLI** configurado con credenciales
   ```bash
   aws configure
   ```

2. **Terraform** >= 1.5
   ```bash
   terraform --version
   ```

3. **kubectl** para interactuar con el cluster
   ```bash
   kubectl version --client
   ```

4. **Permisos IAM** necesarios:
   - EKS Full Access
   - VPC Full Access
   - RDS Full Access
   - EC2 Full Access
   - IAM (para roles de servicio)

## Uso

### 1. Configurar Variables

Copiar el archivo de ejemplo y editar valores:

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Variables críticas a configurar:**
- `db_password`: Contraseña segura para PostgreSQL
- `jwt_secret`: Secret para autenticación JWT
- `aws_region`: Región de AWS (default: eu-west-1)
- `cluster_name`: Nombre del cluster (default: retrogame-eks)

**Opción alternativa (más segura):** Usar variables de entorno:

```bash
export TF_VAR_db_password="tu-password-seguro"
export TF_VAR_jwt_secret="tu-jwt-secret-seguro"
```

### 2. Inicializar Terraform

```bash
terraform init
```

Esto descarga los providers necesarios y configura el backend.

### 3. Planificar el Despliegue

```bash
terraform plan
```

Revisa los recursos que se crearán (aprox. 50+ recursos).

### 4. Aplicar la Infraestructura

```bash
terraform apply
```

⏱️ **Tiempo estimado:** 10-12 minutos (Fargate es más rápido que EC2)

El proceso creará:
- VPC con subnets públicas
- EKS Cluster con Fargate Profiles
- RDS PostgreSQL (db.t3.micro)
- S3 + CloudFront CDN
- Load Balancer para Kong
- Todos los recursos de Kubernetes

### 5. Configurar kubectl

Una vez completado el despliegue, ejecuta:

```bash
aws eks update-kubeconfig --region eu-west-1 --name retrogame-eks
```

Verifica la conexión:

```bash
kubectl get nodes  # Mostrará "fargate-xxxxx" nodes
kubectl get pods -n retrogame
```

### 6. Obtener URL de Acceso

El Load Balancer de Kong es el punto de entrada:

```bash
terraform output kong_load_balancer_hostname
```

Accede a la aplicación en:
```
http://<LOAD_BALANCER_HOSTNAME>
```

### 7. Subir Juegos y Assets al CDN

Después del despliegue, sube los archivos estáticos a S3:

```bash
# Subir juegos .jsdos
terraform output -raw upload_games_command | bash

# Subir imágenes
terraform output -raw upload_images_command | bash
```

O manualmente desde el directorio raíz del proyecto:

```bash
aws s3 sync ./infraestructure/cdn/juegos/ s3://retrogame-games-cdn/juegos/ --region eu-west-1
aws s3 sync ./infraestructure/cdn/img/ s3://retrogame-games-cdn/img/ --region eu-west-1
```

Verifica la URL del CDN:

```bash
terraform output cdn_url
# Output: https://d1234567890.cloudfront.net
```

Los juegos estarán disponibles en:
- `https://<CLOUDFRONT_URL>/juegos/doom.jsdos`
- `https://<CLOUDFRONT_URL>/img/doom.png`

## Outputs Importantes

Después del `terraform apply`, obtendrás:

```bash
# Ver todos los outputs
terraform output

# Outputs específicos
terraform output cluster_name
terraform output cluster_endpoint
terraform output rds_endpoint
terraform output kong_load_balancer_hostname
```

## Costos Estimados 💰

### Entorno Dev con Fargate (configuración actual)

| Recurso | Tipo | Costo Mensual (aprox.) |
|---------|------|------------------------|
| EKS Cluster | Control Plane | $73 |
| **Fargate Compute** | 5 pods (vCPU + memoria) | **$120** |
| RDS PostgreSQL | db.t3.micro | $15 |
| Load Balancer | NLB | $16 |
| CloudFront + S3 | CDN | $5 |
| **TOTAL** | | **~$229/mes** |

#### Desglose Fargate:
- Backend x2: 0.5 vCPU + 1GB = $60/mes
- Frontend x2: 0.25 vCPU + 512MB = $30/mes
- Kong x1: 0.5 vCPU + 1GB = $30/mes

### Comparativa con EC2 Node Groups

| Opción | Costo Mensual | Pros | Contras |
|--------|---------------|------|---------|
| **Fargate** | **$229** | Sin gestión de nodos, sin NAT Gateway, más simple | Más caro por vCPU |
| EC2 (t3.medium x2) | $195 | Más barato para uso constante | Gestión de nodos, NAT Gateway, timeouts |
| EC2 (t4g.medium ARM x2) | $170 | Más económico | Requiere imágenes ARM, gestión |

**Ventajas de Fargate:**
- ✅ **Sin NAT Gateway**: Ahorro de $32/mes vs EC2
- ✅ **Sin gestión**: No más node groups stuck 15 minutos
- ✅ **Pago justo**: Solo pagas lo que usas (5 pods activos)
- ✅ **Escalado instantáneo**: Sin esperar aprovisionamiento de nodos

## Escalabilidad

### Fargate Autoscaling

Fargate escala automáticamente pods sin gestionar capacidad de nodos:

```bash
# Escalar backend
kubectl scale deployment backend -n retrogame --replicas=5
```

Cada pod adicional consumirá:
- Backend: 0.5 vCPU + 1GB = ~$30/mes
- Frontend: 0.25 vCPU + 512MB = ~$15/mes

### Resource Requests/Limits

Configurados para cumplir requisitos mínimos de Fargate:

```yaml
requests:
  cpu: 250m     # Mínimo Fargate: 0.25 vCPU
  memory: 512Mi # Mínimo Fargate: 0.5 GB
limits:
  cpu: 500m
  memory: 1Gi
```

**Importante:** Fargate cobra por el mayor valor entre requests y limits.

## Monitoreo y Logs

### CloudWatch Logs

RDS PostgreSQL exporta logs a CloudWatch:
- `postgresql` - Logs de consultas
- `upgrade` - Logs de actualizaciones

### Kubernetes Metrics

Metrics Server habilitado por defecto:

```bash
kubectl top nodes
kubectl top pods -n retrogamecloud
```

### Ver logs de pods

```bash
# Backend
kubectl logs -n retrogame deployment/backend --tail=50 -f

# Kong
kubectl logs -n retrogame deployment/kong --tail=50 -f

# Ver logs de Fargate nodes
kubectl get pods -n retrogame -o wide
```

## Troubleshooting

### Pods en estado Pending

```bash
kubectl describe pod <pod-name> -n retrogame
```

Posibles causas con Fargate:
- **Resource requests inválidos**: Fargate requiere mínimo 0.25 vCPU y 512Mi
- **Namespace sin Fargate profile**: Verificar que exista profile para el namespace
- **Imagen no encontrada**: DockerHub rate limit o imagen inexistente
- **Secrets/ConfigMaps faltantes**

Verificar Fargate profiles:

```bash
aws eks list-fargate-profiles --cluster-name retrogame --region eu-west-1
aws eks describe-fargate-profile --cluster-name retrogame --fargate-profile-name retrogame-retrogame --region eu-west-1
```

### RDS Connection Timeout

Verificar Security Groups:

```bash
# Con Fargate, los pods tienen IPs públicas en subnets públicas
# Verificar que RDS Security Group permita conexiones desde el CIDR de VPC
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=retrogame-rds-sg"
```

### Load Balancer no responde

```bash
# Verificar estado del servicio
kubectl get svc kong-service -n retrogame

# Verificar eventos
kubectl describe svc kong-service -n retrogame
```

El NLB puede tardar 2-3 minutos en estar completamente operativo.

## Mantenimiento

### Actualizar imágenes Docker

1. Pushear nueva imagen a DockerHub:
   ```bash
   docker push retrogamecloud/backend:v2.0
   ```

2. Actualizar deployment:
   ```bash
   kubectl set image deployment/backend backend=retrogamecloud/backend:v2.0 -n retrogame
   ```

3. Con Fargate, el nuevo pod se creará automáticamente sin gestionar capacidad de nodos

### Backup de RDS

Configurado automáticamente:
- **Dev:** 1 día de retención
- **Prod:** 7 días de retención

Crear snapshot manual:

```bash
aws rds create-db-snapshot \
  --db-instance-identifier retrogame-eks-postgres \
  --db-snapshot-identifier retrogame-manual-backup-$(date +%Y%m%d)
```

### Actualizar Kubernetes

```bash
# Actualizar versión en terraform.tfvars
cluster_version = "1.32"

# Aplicar cambios (Fargate se actualiza automáticamente)
terraform apply
```

⚠️ **Nota:** Con Fargate no gestionas node groups, AWS actualiza la plataforma automáticamente.

## Destruir Infraestructura

⚠️ **ADVERTENCIA:** Esto eliminará TODOS los recursos y datos.

```bash
terraform destroy
```

Confirma escribiendo `yes`.

Para entornos de producción, asegúrate de:
1. Crear backup de RDS
2. Exportar datos críticos
3. Notificar al equipo

## Seguridad

### Mejores Prácticas Implementadas

✅ **Network Isolation**
- VPC dedicada con subnets públicas para Fargate
- Security Groups con reglas restrictivas
- RDS solo accesible desde EKS VPC CIDR

✅ **Secrets Management**
- Secrets de Kubernetes para credenciales
- Variables sensibles marcadas como `sensitive = true`
- Passwords no hardcodeados

✅ **Encryption**
- RDS storage encriptado
- Tráfico CloudFront con HTTPS

✅ **Serverless**
- Sin gestión de EC2 instances
- AWS maneja seguridad de compute layer

### Recomendaciones Adicionales

🔒 **Producción:**
1. Usar AWS Secrets Manager para secrets
2. Habilitar Pod Security Policies
3. Configurar Network Policies
4. Habilitar audit logging en EKS
5. Implementar WAF en Load Balancer
6. Usar imágenes privadas en ECR

## Backend State (Opcional)

Para equipos, configurar S3 backend en `provider.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "tu-bucket-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

Crear recursos previos:

```bash
aws s3 mb s3://tu-bucket-terraform-state
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

## CI/CD Integration

Ejemplo de pipeline con GitHub Actions:

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: terraform init
        
      - name: Terraform Plan
        run: terraform plan
        
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
```

## Soporte

Para problemas o preguntas:
- Revisar logs de Terraform: `terraform.log`
- Revisar logs de Kubernetes: `kubectl logs`
- Consultar documentación de AWS EKS
- Abrir issue en el repositorio

## Licencia

Este proyecto es parte de RetroGameCloud.
