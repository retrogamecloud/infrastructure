# Configuración de GitHub OAuth para ArgoCD

## Pasos para configurar GitHub OAuth

### 1. Crear GitHub OAuth App

1. Ve a tu organización en GitHub: https://github.com/organizations/retrogamecloud/settings/applications
2. Click en **"OAuth Apps"** → **"New OAuth App"**
3. Configura:
   - **Application name**: `ArgoCD - RetroGameCloud`
   - **Homepage URL**: `https://retrogamehub.games`
   - **Authorization callback URL**: `https://retrogamehub.games/argocd/api/dex/callback`
4. Click **"Register application"**
5. Copia el **Client ID**
6. Genera un **Client Secret** y cópialo

### 2. Configurar ArgoCD

#### Opción A: Aplicar ConfigMap y Secret directamente

```bash
# 1. Editar argocd-cm-github.yaml y reemplazar $GITHUB_CLIENT_ID
sed -i 's/$GITHUB_CLIENT_ID/TU_CLIENT_ID_AQUI/g' infrastructure/argocd/github-oauth/argocd-cm-github.yaml

# 2. Editar argocd-secret-github.yaml y reemplazar el client secret
sed -i 's/GITHUB_OAUTH_CLIENT_SECRET_AQUI/TU_CLIENT_SECRET_AQUI/g' infrastructure/argocd/github-oauth/argocd-secret-github.yaml

# 3. Aplicar configuraciones
kubectl apply -f infrastructure/argocd/github-oauth/argocd-cm-github.yaml
kubectl apply -f infrastructure/argocd/github-oauth/argocd-secret-github.yaml

# 4. Reiniciar ArgoCD server y dex para aplicar cambios
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-dex-server -n argocd
```

#### Opción B: Usar kubectl patch (recomendado para producción)

```bash
# Crear secret con GitHub OAuth
kubectl create secret generic argocd-github-oauth \
  -n argocd \
  --from-literal=clientId='TU_CLIENT_ID_AQUI' \
  --from-literal=clientSecret='TU_CLIENT_SECRET_AQUI' \
  --dry-run=client -o yaml | kubectl apply -f -

# Actualizar argocd-secret
CLIENT_SECRET=$(echo -n 'TU_CLIENT_SECRET_AQUI' | base64)
kubectl patch secret argocd-secret -n argocd --type merge -p "{\"data\":{\"dex.github.clientSecret\":\"$CLIENT_SECRET\"}}"

# Actualizar argocd-cm con GitHub config
kubectl patch configmap argocd-cm -n argocd --type merge -p '
{
  "data": {
    "url": "https://retrogamehub.games/argocd",
    "dex.config": "connectors:\n- type: github\n  id: github\n  name: GitHub\n  config:\n    clientID: TU_CLIENT_ID_AQUI\n    clientSecret: $dex.github.clientSecret\n    orgs:\n    - name: retrogamecloud\n",
    "policy.default": "role:readonly",
    "policy.csv": "g, retrogamecloud:*, role:admin\n"
  }
}'

# Reiniciar ArgoCD
kubectl rollout restart deployment/argocd-server deployment/argocd-dex-server -n argocd
```

### 3. Verificar configuración

```bash
# Ver logs de dex
kubectl logs -n argocd deployment/argocd-dex-server -f

# Ver logs de server
kubectl logs -n argocd deployment/argocd-server -f

# Verificar ConfigMap
kubectl get configmap argocd-cm -n argocd -o yaml

# Verificar Secret
kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.dex\.github\.clientSecret}' | base64 -d
```

### 4. Probar autenticación

1. Ve a: https://retrogamehub.games/argocd
2. Click en **"LOG IN VIA GITHUB"**
3. Autoriza la aplicación OAuth
4. Deberías ser redirigido a ArgoCD con acceso admin (si eres miembro de retrogamecloud)

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
