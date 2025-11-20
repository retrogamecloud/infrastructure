# ArgoCD Applications

Este directorio contiene las definiciones de las aplicaciones de ArgoCD para el proyecto RetroGameHub.

## Estructura

```
argocd/
├── apps/
│   ├── backend-app.yaml    # Aplicación backend (database-service)
│   ├── frontend-app.yaml   # Aplicación frontend (gamehub-frontend)
│   └── kong-app.yaml       # Aplicación Kong (API Gateway)
└── README.md
```

## Aplicar las aplicaciones

Una vez que ArgoCD esté instalado y configurado:

```bash
# Aplicar todas las aplicaciones
kubectl apply -f argocd/apps/

# O aplicar individualmente
kubectl apply -f argocd/apps/backend-app.yaml
kubectl apply -f argocd/apps/frontend-app.yaml
kubectl apply -f argocd/apps/kong-app.yaml
```

## Verificar el estado

```bash
# Ver todas las aplicaciones
kubectl get applications -n argocd

# Ver detalles de una aplicación específica
kubectl describe application backend -n argocd

# Verificar sincronización
argocd app list
argocd app get backend
```

## Sincronización manual

Si necesitas forzar una sincronización:

```bash
argocd app sync backend
argocd app sync frontend
argocd app sync kong
```

## Configuración de repositorios

Los repositorios deben estar configurados en ArgoCD. Puedes hacerlo mediante:

1. **ArgoCD UI**: Settings > Repositories > Connect Repo
2. **CLI**:
```bash
argocd repo add https://github.com/retrogamecloud/infrastructure.git
```

## Políticas de sincronización

Todas las aplicaciones están configuradas con:
- **Automated sync**: Se sincronizan automáticamente cuando detectan cambios
- **Self-heal**: Se autocorrigen si los recursos son modificados manualmente
- **Prune**: Eliminan recursos que ya no están definidos en Git

## Notas importantes

- Los manifiestos de Kubernetes están en `k8s/` en la raíz del repositorio
- El placeholder `IMAGE_PLACEHOLDER` en los deployments será actualizado por CI/CD
- Los secrets deben ser creados manualmente o mediante un gestor de secrets externo
- La rama por defecto es `main`, pero puede ser cambiada en cada definición de app
