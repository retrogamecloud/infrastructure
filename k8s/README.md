# Kubernetes Manifests

Este directorio contiene los manifiestos de Kubernetes para las aplicaciones de RetroGameHub, gestionados por ArgoCD.

## Estructura

```
k8s/
├── backend/
│   ├── deployment.yaml   # Deployment del backend (database-service)
│   ├── service.yaml      # Service del backend
│   └── secrets.yaml      # Template de secrets (NO USAR EN PRODUCCIÓN)
├── frontend/
│   ├── deployment.yaml   # Deployment del frontend (gamehub-frontend)
│   └── service.yaml      # Service del frontend
├── kong/
│   ├── deployment.yaml   # Deployment de Kong (API Gateway)
│   ├── service.yaml      # Services de Kong (proxy y admin)
│   └── configmap.yaml    # Configuración de Kong
└── README.md
```

## Aplicaciones

### Backend (database-service)
- **Puerto**: 3000
- **Réplicas**: 2
- **Imagen**: Actualizada automáticamente por CI/CD
- **Dependencias**: PostgreSQL RDS, Redis (opcional)

### Frontend (gamehub-frontend)
- **Puerto**: 8080
- **Réplicas**: 2
- **Imagen**: Actualizada automáticamente por CI/CD
- **Variables**: API_URL, CDN_URL

### Kong (API Gateway)
- **Puertos**: 8000 (proxy), 8001 (admin), 8443 (proxy-ssl), 8444 (admin-ssl)
- **Réplicas**: 2
- **Modo**: DB-less (configuración declarativa)

## Gestión con ArgoCD

Estos manifiestos son monitoreados y sincronizados automáticamente por ArgoCD desde el repositorio Git.

### Ver estado actual
```bash
argocd app get backend
argocd app get frontend
argocd app get kong
```

### Sincronización manual
```bash
argocd app sync backend
argocd app sync frontend
argocd app sync kong
```

## CI/CD Pipeline

### Flujo de actualización de imágenes

1. **Push a rama main** en backend/frontend/kong
2. **GitHub Actions** construye la imagen Docker
3. **Push a ECR/Registry** con tag basado en commit SHA
4. **GitHub Actions actualiza** el deployment.yaml en este repositorio
5. **ArgoCD detecta cambios** y sincroniza automáticamente
6. **Rolling update** en Kubernetes

### Ejemplo de actualización automática por CI/CD

```yaml
# En deployment.yaml antes
image: IMAGE_PLACEHOLDER

# Después del CI/CD
image: <account>.dkr.ecr.us-east-1.amazonaws.com/backend:abc1234
```

## Secrets Management

⚠️ **IMPORTANTE**: El archivo `backend/secrets.yaml` es solo un template.

### Opciones recomendadas para producción:

1. **External Secrets Operator**
```bash
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
```

2. **Sealed Secrets**
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

3. **AWS Secrets Manager con IRSA**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/backend-secrets-role
```

4. **Creación manual** (desarrollo/testing)
```bash
kubectl create secret generic backend-secrets \
  --from-literal=db-host=YOUR_RDS_ENDPOINT \
  --from-literal=db-name=retrogame_db \
  --from-literal=db-user=YOUR_USER \
  --from-literal=db-password=YOUR_PASSWORD \
  --from-literal=jwt-secret=YOUR_JWT_SECRET
```

## Health Checks

Todas las aplicaciones tienen configurados:
- **Liveness Probe**: Verifica que el contenedor está vivo
- **Readiness Probe**: Verifica que está listo para recibir tráfico

Endpoint de health check: `/health` en cada servicio

## Resources

Cada aplicación tiene definidos:
- **Requests**: CPU/Memory mínimos garantizados
- **Limits**: CPU/Memory máximos permitidos

Esto permite al scheduler de Kubernetes optimizar la distribución de pods.

## Troubleshooting

### Ver logs de un deployment
```bash
kubectl logs -f deployment/backend
kubectl logs -f deployment/frontend
kubectl logs -f deployment/kong
```

### Ver estado de los pods
```bash
kubectl get pods -l app=backend
kubectl get pods -l app=frontend
kubectl get pods -l app=kong
```

### Describir un pod con problemas
```bash
kubectl describe pod <pod-name>
```

### Ver eventos del namespace
```bash
kubectl get events --sort-by='.lastTimestamp'
```
