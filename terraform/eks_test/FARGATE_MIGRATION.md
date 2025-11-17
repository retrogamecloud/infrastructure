# Migración a EKS Fargate

## Cambios Realizados

### ✅ Infraestructura

#### VPC (`eks.tf`)
- ❌ **Eliminado**: NAT Gateway (`enable_nat_gateway = false`)
- ✅ **Ahorro**: $32/mes
- ✅ **Fargate usa subnets públicas**: Los pods tienen IPs públicas directamente

#### EKS Cluster (`eks.tf`)
- ❌ **Eliminado**: `eks_managed_node_groups` (EC2 instances)
- ✅ **Agregado**: `fargate_profiles` para namespaces:
  - `kube-system`: CoreDNS y componentes del sistema
  - `default`: Namespace default
  - `retrogame`: Aplicaciones de RetroGameCloud

#### CoreDNS Configuration
- ✅ **Actualizado**: CoreDNS para correr en Fargate
  ```hcl
  computeType = "Fargate"
  ```

#### Security Groups
- ❌ **Eliminado**: `aws_security_group.node_group`
- ✅ **Agregado**: `aws_security_group.fargate_pod`
- ✅ **RDS**: Ahora acepta conexiones desde VPC CIDR (pods en subnets públicas)

### ✅ Aplicaciones Kubernetes

#### Namespace (`kubernetes.tf`)
- ✅ **Cambiado**: `retrogamecloud` → `retrogame` (coincide con Fargate profile)

#### Resource Requests/Limits
Todos los deployments actualizados para cumplir mínimos de Fargate:

**Backend (antes):**
```yaml
requests:
  cpu: 100m
  memory: 128Mi
```

**Backend (ahora):**
```yaml
requests:
  cpu: 250m    # Fargate mínimo: 0.25 vCPU
  memory: 512Mi # Fargate mínimo: 512Mi
limits:
  cpu: 500m
  memory: 1Gi
```

**Frontend (ahora):**
```yaml
requests:
  cpu: 250m
  memory: 512Mi
limits:
  cpu: 250m    # Frontend es ligero
  memory: 512Mi
```

**Kong (ahora):**
```yaml
requests:
  cpu: 250m
  memory: 512Mi
limits:
  cpu: 500m
  memory: 1Gi
```

### ✅ Outputs

- ❌ **Eliminado**: `node_security_group_id`
- ✅ **Agregado**: `fargate_pod_security_group_id`

## Costos Comparativos

### Antes (EC2 Node Groups)
```
EKS Control Plane:     $73/mes
EC2 (2x t3.medium):    $60/mes
NAT Gateway:           $32/mes
RDS (db.t3.micro):     $15/mes
NLB:                   $16/mes
CloudFront + S3:       $5/mes
--------------------------------
TOTAL:                 $201/mes
```

### Ahora (Fargate)
```
EKS Control Plane:     $73/mes
Fargate Compute:       $120/mes
  - Backend x2:        $60/mes (0.5 vCPU + 1GB cada)
  - Frontend x2:       $30/mes (0.25 vCPU + 512MB cada)
  - Kong x1:           $30/mes (0.5 vCPU + 1GB)
RDS (db.t3.micro):     $15/mes
NLB:                   $16/mes
CloudFront + S3:       $5/mes
--------------------------------
TOTAL:                 $229/mes
```

**Diferencia: +$28/mes (14% más caro)**

## Ventajas de Fargate

✅ **Sin gestión de nodos**
- No más `node groups` stuck 15 minutos
- AWS maneja patching, scaling, seguridad

✅ **Sin NAT Gateway**
- Ahorro de $32/mes
- Pods tienen IPs públicas directamente

✅ **Despliegue más rápido**
- Pods inician en 30-60 segundos
- vs 10-15 minutos para node groups EC2

✅ **Pago por uso exacto**
- Solo pagas por vCPU/memoria de pods activos
- Sin overhead de EC2 instances

✅ **Autoscaling transparente**
- Escalar pods no requiere gestionar capacidad
- AWS aprovisiona compute automáticamente

## Desventajas de Fargate

❌ **14% más caro** ($229 vs $201)
- Para cargas 24/7 constantes

❌ **Restricciones**
- No soporta DaemonSets
- No soporta privileged containers
- No soporta hostNetwork

❌ **Cold start**
- Primera pod tarda ~60s vs ~10s en EC2 existente

## ¿Cuándo usar cada opción?

### Usar Fargate si:
- ✅ Quieres **cero gestión** de infraestructura
- ✅ Tu carga es **variable/impredecible**
- ✅ Valoras **simplicidad** sobre costo
- ✅ Tienes 5-10 pods estables

### Usar EC2 Node Groups si:
- ✅ Tu carga es **24/7 constante**
- ✅ Necesitas **máximo control**
- ✅ Requieres DaemonSets o containers privilegiados
- ✅ Priorizas **costo mínimo**

## Plan de Despliegue

### 1. Verificar configuración
```bash
cd /mnt/c/proyecto_final/infraestructure/terraform/eks_test
terraform validate
terraform plan
```

### 2. Desplegar infraestructura
```bash
terraform apply -auto-approve
```

⏱️ **Tiempo estimado: 10-12 minutos** (vs 15-20 con EC2)

### 3. Configurar kubectl
```bash
aws eks update-kubeconfig --region eu-west-1 --name retrogame
```

### 4. Verificar pods
```bash
kubectl get pods -n retrogame -o wide
```

Deberías ver pods con nodos tipo `fargate-ip-xxx`

### 5. Verificar Fargate profiles
```bash
aws eks list-fargate-profiles --cluster-name retrogame --region eu-west-1
aws eks describe-fargate-profile \
  --cluster-name retrogame \
  --fargate-profile-name retrogame-retrogame \
  --region eu-west-1
```

### 6. Subir assets a CDN
```bash
terraform output -raw upload_games_command | bash
terraform output -raw upload_images_command | bash
```

### 7. Obtener URL de acceso
```bash
terraform output kong_load_balancer_hostname
```

## Troubleshooting Fargate

### Pods en Pending

**Verificar namespace tiene Fargate profile:**
```bash
kubectl get pod <pod-name> -n retrogame -o yaml | grep -A 5 schedulerName
```

Debe mostrar `fargate-scheduler` o similar.

**Verificar resource requests:**
```bash
kubectl describe pod <pod-name> -n retrogame
```

Mínimos Fargate:
- CPU: 250m (0.25 vCPU)
- Memory: 512Mi

### Pods sin acceso a Internet

**Verificar subnets tienen Internet Gateway:**
```bash
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=retrogame-vpc-public"
```

Debe tener ruta `0.0.0.0/0` → Internet Gateway

### RDS Connection Failed

**Verificar Security Group permite VPC CIDR:**
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=retrogame-rds-sg" \
  --query 'SecurityGroups[0].IpPermissions'
```

Debe permitir puerto 5432 desde CIDR `10.0.0.0/16`

## Rollback a EC2 Node Groups

Si necesitas volver a EC2:

```bash
git checkout <commit-antes-fargate>
terraform apply
```

O revisar commit anterior de `eks.tf` con node groups.

## Referencias

- [AWS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [EKS Fargate Documentation](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [Fargate Pod Configuration](https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html)
