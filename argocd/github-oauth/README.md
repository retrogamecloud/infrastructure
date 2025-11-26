# Configuración de GitHub OAuth para ArgoCD

⚠️ **NOTA**: Esta es la configuración legacy para aplicación manual.  
**Para gestión persistente con GitOps**, usa: `kubernetes/argocd-config/`

---

## ✅ Configuración simplificada - Reutilizando OAuth2 Proxy existente

Este proyecto ya tiene configurado **OAuth2 Proxy** en el namespace `monitoring` con autenticación GitHub para la organización `retrogamecloud`. ArgoCD puede **reutilizar el mismo GitHub OAuth App**, simplificando la configuración.

### Credenciales compartidas

- **Client ID**: `Ov23lil4DINdiuLj2XnS` (ya configurado)
- **Client Secret**: `0e14645efdb0317bd3c83c9ace9a76f198b53052` (copiado desde oauth2-proxy)
- **Organización**: `retrogamecloud`
- **Callback URL ArgoCD**: `https://retrogamehub.games/argocd/api/dex/callback`

## 🚀 Configuración Persistente con GitOps (Recomendado)

Para que la configuración sea persistente y gestionada por ArgoCD:

```bash
# Ver documentación completa
cd ../../../kubernetes/argocd-config
cat README.md

# Aplicar con ArgoCD Application
kubectl apply -f argocd-config-app.yaml

# O con Kustomize directamente
kubectl apply -k overlays/production
```

## Pasos para aplicar (simplificados)

### 1. Añadir callback URL en GitHub OAuth App existente

1. Ve a: https://github.com/settings/developers (o settings de la org si el OAuth App está allí)
2. Click en el OAuth App que usa oauth2-proxy (Client ID: `Ov23lil4DINdiuLj2XnS`)
3. En **"Authorization callback URLs"**, añade:
   ```
   https://retrogamehub.games/argocd/api/dex/callback
   ```
4. Click **"Update application"**

### 2. Aplicar configuraciones en el cluster

```bash
# Los archivos YA tienen las credenciales correctas reutilizadas
kubectl apply -f infrastructure/argocd/github-oauth/argocd-cm-github.yaml
kubectl apply -f infrastructure/argocd/github-oauth/argocd-secret-github.yaml

# Reiniciar ArgoCD para aplicar cambios
kubectl rollout restart deployment/argocd-server deployment/argocd-dex-server -n argocd
```

### 3. Verificar y probar

```bash
# Esperar a que los pods estén running
kubectl get pods -n argocd -w

# Ver logs si hay problemas
kubectl logs -n argocd deployment/argocd-dex-server -f
kubectl logs -n argocd deployment/argocd-server -f
```

**Probar autenticación:**
1. Ve a: https://retrogamehub.games/argocd
2. Deberías ver botón **"LOG IN VIA GITHUB"**
3. Click → Autoriza (ya autorizado si usaste oauth2-proxy antes)
4. Acceso admin automático (miembro de retrogamecloud)

### 5. Gestionar acceso

#### Ver usuarios autenticados
```bash
kubectl exec -n argocd deployment/argocd-server -- argocd account list
```

#### Revocar sesiones
```bash
# Revocar todas las sesiones de un usuario
kubectl exec -n argocd deployment/argocd-server -- argocd account logout <username>
```

#### Actualizar políticas RBAC
Edita el ConfigMap `argocd-cm` sección `policy.csv`:
```bash
kubectl edit configmap argocd-cm -n argocd
```

## Políticas de acceso configuradas

### Por defecto
- **Usuarios no autenticados**: Sin acceso
- **Miembros de retrogamecloud**: Acceso admin completo

### Políticas RBAC disponibles

```csv
# Admin completo para toda la org
g, retrogamecloud:*, role:admin

# Acceso granular por teams (ejemplo)
g, retrogamecloud:admins, role:admin
g, retrogamecloud:developers, role:developer
g, retrogamecloud:viewers, role:readonly

# Permisos personalizados para rol developer
p, role:developer, applications, *, */*, allow
p, role:developer, repositories, get, *, allow
p, role:developer, repositories, sync, *, allow
p, role:developer, logs, get, *, allow
p, role:developer, exec, create, */*, deny
```

## Troubleshooting

### Error: "Failed to authenticate"
- Verifica que el Client ID y Secret sean correctos
- Verifica que la callback URL sea exactamente: `https://retrogamehub.games/argocd/api/dex/callback`

### Error: "User is not a member of required organization"
- Verifica que el usuario sea miembro de la org `retrogamecloud` en GitHub
- Verifica la configuración en `argocd-cm` sección `orgs`

### No aparece botón "LOG IN VIA GITHUB"
- Verifica que dex-server esté corriendo: `kubectl get pods -n argocd`
- Verifica logs: `kubectl logs -n argocd deployment/argocd-dex-server`
- Reinicia server: `kubectl rollout restart deployment/argocd-server -n argocd`

### Cambios en ConfigMap no se aplican
- Reinicia los deployments después de cada cambio en ConfigMaps o Secrets
- Los cambios en RBAC requieren reiniciar solo argocd-server
- Los cambios en OAuth requieren reiniciar dex-server y argocd-server

## Desactivar autenticación con password

Una vez configurado GitHub OAuth, puedes deshabilitar el usuario admin local:

```bash
# Deshabilitar admin password
kubectl patch secret argocd-secret -n argocd --type merge -p '{"data":{"admin.enabled":"ZmFsc2U="}}'

# Reiniciar server
kubectl rollout restart deployment/argocd-server -n argocd
```

**IMPORTANTE**: Solo desactives el admin después de verificar que GitHub OAuth funciona correctamente.

## Referencias

- [ArgoCD SSO Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
- [Dex GitHub Connector](https://dexidp.io/docs/connectors/github/)
- [ArgoCD RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
