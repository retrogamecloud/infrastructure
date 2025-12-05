# ArgoCD - Configuración GitOps

Este directorio contiene la configuración de ArgoCD para la gestión declarativa y automatizada de despliegues en Kubernetes. Implementa GitOps, sincronización automática de manifiestos y notificaciones de cambios.

## Índice

1. [Descripción del repositorio](#descripción-del-repositorio)
2. [Funcionalidad del repositorio](#funcionalidad-del-repositorio)
   - [Componentes principales](#componentes-principales)
3. [Stack tecnológico](#stack-tecnológico)
   - [Herramientas y versiones](#herramientas-y-versiones)
   - [Integraciones externas](#integraciones-externas)
   - [RBAC y permisos](#rbac-y-permisos)
4. [Guía de uso/despliegue](#guía-de-usodeploye)
   - [Prerrequisitos](#prerrequisitos)
   - [Paso 1: Instalación inicial de ArgoCD](#paso-1-instalación-inicial-de-argocd)
   - [Paso 2: Aplicar configuración](#paso-2-aplicar-configuración-desde-este-directorio)
   - [Paso 3: Configurar GitHub OAuth](#paso-3-configurar-github-oauth)
   - [Paso 4: Configurar Slack Notifications](#paso-4-configurar-slack-notifications)
   - [Paso 5: Configurar Ingress y certificados SSL](#paso-5-configurar-ingress-y-certificados-ssl)
   - [Paso 6: Cambiar credenciales admin](#paso-6-cambiar-credenciales-admin)
5. [Personalización y cambios](#personalización-y-cambios)
6. [Revertir cambios](#revertir-cambios)
7. [Seguridad y buenas prácticas](#seguridad-y-buenas-prácticas)
8. [Referencias](#referencias)

---

## Descripción del repositorio

ArgoCD es una herramienta GitOps que monitorea repositorios Git y sincroniza automáticamente el estado del cluster Kubernetes con lo declarado en Git. Esta configuración establece:

- **Gestión centralizada:** Todas las aplicaciones (backend, frontend) se definen en un único Application resource.
- **Sincronización automática:** Cambios en Git se aplican automáticamente al cluster (auto-sync).
- **Auto-healing:** Detecta y revierte cambios manuales en el cluster.
- **Seguridad con OAuth:** Integración con GitHub para autenticación y autorización.
- **Notificaciones Slack:** Alertas en despliegues, fallos de sincronización y degradaciones de salud.
- **RBAC:** Control de acceso basado en roles y grupos de GitHub.

## Funcionalidad del repositorio

### Componentes principales

#### 1. Application Resource (`argocd-config-app.yaml`)
```yaml
kind: Application
metadata:
  name: argocd-config
```

**Propósito:** Aplicación ArgoCD autogestionada que sincroniza su propia configuración

**Características:**
- Monitorea rama `main` en `argocd/overlays/production`
- Sincronización automática habilitada (`automated`)
- Poda automática de recursos eliminados (`prune: true`)
- Auto-healing activo (`selfHeal: true`)
- Aplica cambios usando Server-Side Apply (recomendado en Kubernetes 1.30+)

#### 2. Configuración Base (`base/`)

Contiene la configuración estable y reutilizable:

- **`argocd-secret.yaml`:** Credenciales e integración con repositorios Git (GH token, credenciales privadas)
- **`argocd-cm-patch.yaml`:** ConfigMap patch para URL de ArgoCD y OAuth con GitHub (Dex connector)
- **`argocd-rbac-cm.yaml`:** Control de acceso - permisos por usuario/grupo de GitHub
- **`argocd-ingress.yaml`:** Exposición via NGINX Ingress en `https://retrogamehub.games/argocd`
- **`argocd-notifications-cm.yaml`:** Integración con Slack y templates de notificaciones
- **`argocd-notifications-secret.yaml`:** Token de Slack para autenticación
- **`argocd-repo.yaml`** (deshabilitado): Configuración de repo privado (gestionado manualmente)
- **`argocd-repo-infrastructure.yaml`** (deshabilitado): Repo de infraestructura (gestionado manualmente)

#### 3. Overlay Production (`overlays/production/`)

Personalizaciones para ambiente de producción:

- **Inherita configuración base** con Kustomize
- **Labels de ambiente:** Añade `environment: production`
- **Estructura lista para escalabilidad:** Otros ambientes (staging, dev) pueden añadirse fácilmente

## Stack tecnológico

### Herramientas y versiones

| Componente | Versión | Propósito |
|-----------|---------|----------|
| **ArgoCD** | v3.2.x (Helm chart) | GitOps CD platform |
| **Kubernetes** | 1.28+ | Orquestación de contenedores |
| **Kustomize** | v5.x (integrado en kubectl) | Gestión de manifiestos declarativos |
| **NGINX Ingress Controller** | v1.x | Exposición segura de ArgoCD |
| **GitHub** | OAuth 2.0 (Dex connector) | Autenticación centralizada |
| **Slack** | Notifications API | Alertas y observabilidad |

### Integraciones externas

#### GitHub OAuth (Dex)
Autenticación centralizada mediante GitHub. Los usuarios de la organización `retrogamecloud` pueden autenticarse directamente con sus credenciales de GitHub, simplificando el acceso y manteniendo sincronizados los permisos con la estructura de la organización.

**Flujo:**
1. Usuario accede a `https://retrogamehub.games/argocd`
2. Redirección a GitHub para autorizar acceso de org `retrogamecloud`
3. Token JWT regresa a ArgoCD
4. RBAC aplica permisos según user/grupo GitHub

#### Slack Notifications
Notificaciones automáticas en Slack sobre eventos críticos de despliegue. Se envían alertas para:
- Despliegues exitosos
- Fallos de sincronización
- Degradaciones de salud de aplicaciones

**Triggers configurados:**
- `on-deployed`: Aplicación sincronizada y saludable
- `on-sync-failed`: Error en sincronización de manifiestos
- `on-health-degraded`: Aplicación degradada o no saludable

#### NGINX Ingress + OAuth2 Proxy
Exposición segura de ArgoCD a través de ingress con redirección SSL y autenticación OAuth2 adicional.

```yaml
host: retrogamehub.games
path: /argocd
ssl-redirect: true
auth-url: https://$host/oauth2/auth
```

### RBAC y permisos

| Usuario | Rol | Permisos |
|---------|-----|----------|
| jpalenz77 | admin | Total acceso, gestión de apps, repos, settings |
| naesman1 | admin | Total acceso |
| evaristogz | admin | Total acceso |
| retrogamecloud:* | admin | Todos los miembros de la org en GitHub (via grupos) |
| Otros usuarios autenticados | readonly | Solo visualizar estado, sin modificaciones |

---

## Guía de uso/despliegue

### Prerrequisitos

1. **Cluster Kubernetes** 1.28+ con NGINX Ingress Controller instalado
2. **ArgoCD** instalado en namespace `argocd`
3. **GitHub OAuth App** creada en org `retrogamecloud` (credenciales configuradas)
4. **Slack Workspace** con bot autorizado y canal `#argocdretrogame`
5. **Dominio DNS:** `retrogamehub.games` apuntando al IP del ingress controller

### Paso 1: Instalación inicial de ArgoCD

```bash
# 1. Crear namespace argocd
kubectl create namespace argocd

# 2. Instalar ArgoCD (últimas versión)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Verificar que pods están running
kubectl get pods -n argocd
# Debe mostrar: argocd-server, argocd-application-controller, argocd-repo-server, etc.

# 4. Obtener contraseña de admin por defecto (guardar para cambiarla)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Paso 2: Aplicar configuración desde este directorio

```bash
# 1. Aplicar configuración base + overlay production
kubectl apply -k argocd/overlays/production/

# 2. Verificar que recursos se crearon
kubectl get configmaps -n argocd
kubectl get secrets -n argocd
kubectl get ingress -n argocd

# 3. Verificar Application resource (autogestionada)
kubectl get application -n argocd
# Debe mostrar: argocd-config (status: Synced/Healthy)
```

**Orden de aplicación:**
1. Secrets (credenciales)
2. ConfigMaps (configuración)
3. Ingress (exposición)
4. Application (orquestación)

### Paso 3: Configurar GitHub OAuth

#### 3.1 Crear OAuth App en GitHub

```
1. Ir a: GitHub Settings > Developer settings > OAuth Apps
2. Click "New OAuth App"
3. Completar formulario:
   - Application name: ArgoCD Retrogame
   - Homepage URL: https://retrogamehub.games/argocd
   - Authorization callback URL: https://retrogamehub.games/argocd/auth/callback
4. Copiar Client ID y Client Secret
```

#### 3.2 Actualizar secret en ArgoCD

```bash
# Editar secret con el Client Secret
kubectl -n argocd edit secret argocd-secret

# Buscar sección "dex.github.clientSecret" y actualizar valor
# El ConfigMap patch ya tiene referencia: clientSecret: $dex.github.clientSecret
```

#### 3.3 Forzar resincronización

```bash
# ArgoCD detecta cambios automáticamente, pero puedes forzar:
argocd app sync argocd-config

# Verificar que cambios se aplicaron
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50
```

### Paso 4: Configurar Slack Notifications

#### 4.1 Crear bot de Slack

```
1. Ir a: api.slack.com > Create New App
2. Seleccionar "From scratch"
3. Nombre: ArgoCD Retrogame
4. Seleccionar workspace: tu workspace
5. En "OAuth & Permissions" > "Scopes" agregar:
   - chat:write
   - files:write
6. Instalar app en workspace
7. Copiar "Bot User OAuth Token"
```

#### 4.2 Actualizar secret en Kubernetes

```bash
# Editar secret de notificaciones
kubectl -n argocd edit secret argocd-notifications-secret

# Formato YAML:
# data:
#   slack-token: <base64-token>

# Convertir token a base64:
echo -n "xoxb-xxxxxxxxxxxx" | base64
```

#### 4.3 Crear/verificar canal en Slack

```bash
# 1. En Slack, crear canal #argocdretrogame (o usar existente)
# 2. Invitar bot ArgoCD al canal
# 3. Verificar que ArgoCD puede escribir (las notificaciones llegarán ahí)
```

### Paso 5: Configurar Ingress y certificados SSL

```bash
# 1. Instalar cert-manager (si no está)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. Crear ClusterIssuer para Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Reemplazar con email válido
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# 3. Actualizar Ingress con cert-manager (si es necesario agregar TLS)
# El archivo argocd-ingress.yaml puede extenderse con:
# tls:
# - hosts:
#   - retrogamehub.games
#   secretName: argocd-tls
# annotations:
#   cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

### Paso 6: Cambiar credenciales admin

```bash
# 1. Acceder a ArgoCD UI con admin y contraseña inicial
# URL: https://retrogamehub.games/argocd

# 2. Settings > Accounts > admin > Update password

# 3. O via CLI:
argocd account update-password \
  --account admin \
  --current-password <initial-password> \
  --new-password <new-password>

# 4. Deshabilitar usuario admin (usar OAuth)
argocd account disable admin
```

---

## Personalización y cambios

### Personalización común: Agregar nueva aplicación

Las aplicaciones reales (backend, frontend) se definen en `kubernetes/` repo, no aquí. Pero este ejemplo muestra la estructura:

```yaml
# Crear: argocd/overlays/production/apps/backend-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/retrogamecloud/kubernetes
    targetRevision: main
    path: apps/backend
  destination:
    server: https://kubernetes.default.svc
    namespace: backend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Luego agregar a `kustomization.yaml`:
```yaml
resources:
  - apps/backend-app.yaml
```

### Personalización: Cambiar URL de ArgoCD

```bash
# Editar base/argocd-cm-patch.yaml
# Cambiar: url: https://retrogamehub.games/argocd
# A: url: https://tu-nuevo-dominio.com/argocd

# Aplicar cambio
kubectl apply -k argocd/overlays/production/
```

### Personalización: Agregar nuevo usuario/grupo RBAC

```bash
# Editar base/argocd-rbac-cm.yaml
# Agregar línea:
# g, <github-username-o-grupo>, role:admin

# Ejemplo:
# g, nuevo-usuario, role:admin
# g, mi-equipo-github, role:readonly

# Aplicar
kubectl apply -k argocd/overlays/production/
```

---

## Revertir cambios

### Escenario 1: Revertir última aplicación de configuración

```bash
# 1. Ver historial de cambios
kubectl rollout history deployment/argocd-server -n argocd

# 2. Si cambio fue hace poco, revertir deployment:
kubectl rollout undo deployment/argocd-server -n argocd

# 3. Verificar que pods reiniciaron
kubectl get pods -n argocd
```

### Escenario 2: Revertir cambio en Git

```bash
# 1. Si aplicaste un cambio que rompió algo:
git revert <commit-hash>
git push origin main

# 2. ArgoCD detecta cambio y sincroniza automáticamente
# (Si auto-sync está habilitado)

# 3. O forzar manualmente:
argocd app sync argocd-config
```

### Escenario 3: Desactivar auto-sync temporalmente

```bash
# Si quieres cambios manuales sin sincronización automática:
argocd app set argocd-config --sync-policy none

# Para reactivar:
argocd app set argocd-config --sync-policy automated --auto-prune --self-heal
```

### Escenario 4: Restaurar versión anterior de manifiestos

```bash
# 1. Ver historial de syncs:
argocd app history argocd-config

# 2. Restaurar a revisión anterior:
argocd app rollback argocd-config <revision-id>

# Alternativamente, git revert es más seguro y documentado
```

### Escenario 5: Limpiar recursos si desinstalación

```bash
# Eliminar ArgoCD completamente
kubectl delete namespace argocd

# Eliminar finalizers si algunos recursos quedan:
kubectl delete applications -n argocd --all --grace-period=0 --force

# Desinstalar ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

## Referencias

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitHub OAuth Integration](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/github-oauth/)
- [ArgoCD Notifications](https://argocd-notifications.readthedocs.io/)
- [RBAC in ArgoCD](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
