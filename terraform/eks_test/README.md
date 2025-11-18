# RetroGameCloud - EKS Deployment con Terraform

Este directorio contiene la infraestructura como código (IaC) para desplegar RetroGameCloud en AWS usando EKS (Elastic Kubernetes Service).

## Arquitectura

- **VPC**: Red privada virtual con subnets públicas y privadas en 3 Availability Zones
- **EKS Cluster**: Kubernetes v1.32 con Node Groups EC2
- **RDS PostgreSQL**: Base de datos gestionada (PostgreSQL 15.15)
- **S3 + CloudFront**: CDN para archivos estáticos (juegos .jsdos, imágenes, emulador)
- **Load Balancer**: Network Load Balancer (NLB) para Kong API Gateway
- **Security Groups**: Aislamiento de red entre componentes
- **Auto-deploy**: Scripts automáticos para inicialización de BD y subida de assets

### ¿Por qué EC2 Node Groups?

✅ **Mayor estabilidad** - Control completo sobre los nodos de computación
✅ **Más económico** - ~$205/mes vs $229 con Fargate
✅ **Mejor rendimiento** - Networking más rápido con ENIs dedicadas
✅ **Persistencia** - Nodos dedicados sin cold starts
✅ **Flexibilidad** - Elección de instance types y configuraciones personalizadas

## Componentes

### Infraestructura AWS
- `provider.tf`: Configuración de providers (AWS, Kubernetes, Helm, Null)
- `variables.tf`: Variables configurables
- `eks.tf`: Cluster EKS v1.32, VPC, Node Groups, Security Groups
- `rds.tf`: RDS PostgreSQL con credenciales en Kubernetes Secret
- `s3-cdn.tf`: S3 Buckets (CDN + logs), CloudFront, auto-upload de assets
- `outputs.tf`: Outputs útiles post-despliegue

### Aplicaciones Kubernetes
- `kubernetes.tf`: Deployments, Services, ConfigMaps, Secrets, Jobs
  - Backend (1 réplica) - 100m CPU, 256MB RAM
  - Frontend (1 réplica) - 50m CPU, 128MB RAM con init containers para URL replacement
  - Kong API Gateway (1 réplica) - 100m CPU, 256MB RAM
  - Job de inicialización de BD (automático)
  - Null resource para actualización de URLs post-deploy

### Observabilidad (Monitoring Stack)
- `monitoring.tf`: Stack completo de Prometheus + Grafana + AlertManager
  - **Prometheus**: Time-series database para métricas (10Gi storage, 3d retention)
  - **Grafana**: Dashboards interactivos pre-configurados (20+ dashboards incluidos)
  - **AlertManager**: Sistema de alertas con notificaciones configurables
  - **Node Exporter**: Métricas de nodos EC2 (CPU, memoria, disco, red)
  - **Kube State Metrics**: Estado del cluster (pods, deployments, services)
  - Namespace separado `monitoring` (no intrusivo)
- `servicemonitors.tf`: Configuración para scrapear métricas de aplicaciones propias
  - ServiceMonitor para Backend (/metrics cada 30s)
  - ServiceMonitor para Frontend (/metrics cada 30s)
  - ServiceMonitor para Kong (/metrics cada 30s)
- `example-prometheus-metrics.js`: Código de ejemplo para instrumentar Node.js apps
- **Ver documentación completa**: [MONITORING_GUIDE.md](./MONITORING_GUIDE.md)

### Automatización
- **Init Containers**: Copian y modifican archivos HTML con URLs correctas
- **Kubernetes Job**: Ejecuta script SQL de inicialización de BD automáticamente
- **Null Resources**: 
  - Subida automática de juegos, imágenes y emulador al CDN
  - Actualización de ConfigMap con URL real del Load Balancer

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

⏱️ **Tiempo estimado:** 15-20 minutos (incluye aprovisionamiento de nodos EC2)

El proceso creará:
- VPC con subnets públicas y privadas
- EKS Cluster con Node Groups EC2 (3x t3.micro)
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
kubectl get nodes  # Mostrará 3 nodos EC2 (ip-10-0-x-x.eu-west-1.compute.internal)
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

### 8. Acceder a Grafana y Prometheus (Monitoring)

Una vez desplegado el stack de monitoring, puedes acceder a Grafana para ver dashboards:

```bash
# Port-forward Grafana a localhost:3000
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Abre en tu navegador: **http://localhost:3000**

**Credenciales por defecto:**
- Usuario: `admin`
- Contraseña: `admin123` (cambiar en producción!)

**Dashboards recomendados:**
- `Kubernetes / Compute Resources / Cluster` - Vista general del cluster
- `Kubernetes / Compute Resources / Namespace (Pods)` - Métricas por namespace
- `Node Exporter / Nodes` - Métricas de nodos EC2
- `Prometheus / Overview` - Estado de Prometheus

**Acceder a Prometheus directamente:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```
Abre: **http://localhost:9090**

**Ver más detalles**: [MONITORING_GUIDE.md](./MONITORING_GUIDE.md)

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

### Entorno Dev con EC2 Node Groups (configuración actual)

| Recurso | Tipo | Costo Mensual (aprox.) |
|---------|------|------------------------|
| EKS Cluster | Control Plane | $73 |
| **EC2 Node Groups** | 3x t3.micro (1 vCPU, 1GB cada uno) | **$30** |
| NAT Gateway | 1x NAT Gateway | **$45** |
| RDS PostgreSQL | db.t3.micro | $20 |
| Load Balancer | NLB | $16 |
| EBS Volumes | 3x 20GB gp3 (nodos) | $6 |
| CloudFront + S3 | CDN | $5 |
| **Monitoring Stack** | Prometheus + Grafana (EBS) | **$10** |
| **TOTAL** | | **~$205/mes** |

#### Desglose EC2 Node Groups:
- 3x t3.micro: $10/mes cada uno = $30/mes
- NAT Gateway: $32.85/mes (730 horas) + ~$12/mes (tráfico) = ~$45/mes
- EBS: 3x 20GB gp3 @ $0.08/GB = $6/mes

#### Desglose Monitoring:
- Prometheus: 10Gi EBS gp3 = ~$0.80/mes
- AlertManager: 2Gi EBS gp3 = ~$0.16/mes
- Grafana: PVC 10Gi = ~$0.80/mes
- Node Exporter DaemonSet: ~200m CPU, 512Mi RAM (distribuido en nodos)
- **Total compute incluido en nodos EC2**
- **Nota**: Si se añade LoadBalancer para Grafana: +$16/mes (no recomendado, usar port-forward)

### Alternativas de Compute

| Opción | Costo Mensual | Pros | Contras |
|--------|---------------|------|---------|
| **EC2 (3x t3.micro)** | **$205** | Económico, control total, estable | Requiere NAT Gateway, gestión básica |
| EC2 (3x t3.small) | $235 | Más recursos (2GB RAM por nodo) | Más caro (+$30/mes) |
| EC2 (3x t4g.micro ARM) | $185 | Más económico (-$20/mes) | Requiere imágenes ARM compatibles |

**Ventajas de EC2 Node Groups:**
- ✅ **Más económico**: $205/mes total
- ✅ **Mayor control**: Acceso SSH, configuración personalizada
- ✅ **Networking optimizado**: ENIs dedicadas, latencia más baja
- ✅ **Sin cold starts**: Nodos siempre activos

## Escalabilidad

### Horizontal Pod Autoscaling (HPA)

Escalar pods basado en CPU/memoria:

```bash
# Crear HPA para backend
kubectl autoscale deployment backend -n retrogame --cpu-percent=70 --min=1 --max=5

# Ver estado del HPA
kubectl get hpa -n retrogame
```

**Nota:** Los 3 nodos t3.micro tienen capacidad total de ~2.5 vCPU y ~2.5GB RAM (después de pods del sistema).

### Cluster Autoscaling (Node Groups)

Configurar autoscaling de nodos EC2:

```bash
# Actualizar min/max size del node group
aws eks update-nodegroup-config \
  --cluster-name retrogame-eks \
  --nodegroup-name retrogame-node-group \
  --scaling-config minSize=2,maxSize=6,desiredSize=3
```

### Resource Requests/Limits

Configurados para optimizar uso de t3.micro nodes:

```yaml
requests:
  cpu: 100m     # Backend: 100m, Frontend: 50m, Kong: 100m
  memory: 256Mi # Backend: 256Mi, Frontend: 128Mi, Kong: 256Mi
limits:
  cpu: 500m
  memory: 512Mi
```

**Capacidad por nodo t3.micro:**
- CPU: 1 vCPU (~900m disponible para pods)
- RAM: 1GB (~700MB disponible para pods)

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

# Ver logs de nodos EC2
kubectl get pods -n retrogame -o wide
kubectl describe node <node-name>
```

## Troubleshooting

### Pods en estado Pending

```bash
kubectl describe pod <pod-name> -n retrogame
```

Posibles causas con EC2 Node Groups:
- **Recursos insuficientes**: Nodos saturados, necesitan escalar
- **Node NotReady**: Nodo EC2 con problemas, verificar status
- **Imagen no encontrada**: DockerHub rate limit o imagen inexistente
- **Secrets/ConfigMaps faltantes**: Verificar que existan en el namespace
- **Taints/Tolerations**: Verificar si hay taints en los nodos

Verificar estado de nodos:

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes  # Ver uso de CPU/RAM
```

### RDS Connection Timeout

Verificar Security Groups:

```bash
# Con EC2 Node Groups, los pods usan IPs privadas
# Verificar que RDS Security Group permita conexiones desde el CIDR de subnets privadas (10.0.0.0/16)
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=retrogame-rds-sg"

# Verificar conectividad desde un pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n retrogame -- \
  psql -h <RDS_ENDPOINT> -U postgres -d retrogame
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

3. Con EC2 Node Groups, el pod se actualizará usando rolling update (max unavailable: 25%, max surge: 25%)

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

# Aplicar cambios
terraform apply
```

⚠️ **Nota:** Con EC2 Node Groups:
1. Primero se actualiza el control plane de EKS
2. Luego se actualiza la versión de Kubernetes en los nodos
3. Los nodos se actualizan mediante rolling update (uno a la vez)
4. Pods se drenan y migran automáticamente

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
- VPC dedicada con subnets públicas y privadas
- Pods en subnets privadas (sin acceso directo a Internet)
- NAT Gateway para tráfico saliente
- Security Groups con reglas restrictivas
- RDS solo accesible desde CIDR de VPC (10.0.0.0/16)

✅ **Secrets Management**
- Secrets de Kubernetes para credenciales
- Variables sensibles marcadas como `sensitive = true`
- Passwords no hardcodeados

✅ **Encryption**
- RDS storage encriptado
- Tráfico CloudFront con HTTPS
- EBS volumes encriptados

✅ **Instance Security**
- EC2 instances con IAM roles (no access keys)
- Security Groups: solo tráfico necesario
- SSM Session Manager para acceso (sin SSH keys)

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
