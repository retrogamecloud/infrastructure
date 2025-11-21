# Configuración de Notificaciones de ArgoCD para Slack

## Requisitos Previos

1. **Crear Slack App**: https://api.slack.com/apps
2. **Configurar Bot Token Scopes** en OAuth & Permissions:
   - `chat:write`
   - `chat:write.public`
3. **Instalar App** en tu workspace
4. **Invitar el bot** al canal `#argocdretrogame`:
   ```
   /invite @NombreDelBot
   ```

## Instalación

### 1. Obtener el Bot Token

Después de instalar la app en tu workspace:
- Ve a **OAuth & Permissions**
- Copia el **Bot User OAuth Token** (empieza con `xoxb-`)

### 2. Crear Secret con el Token

Edita el archivo `argocd-notifications-secret.yaml` y reemplaza `SLACK_BOT_TOKEN_AQUI` con tu token:

```bash
kubectl create secret generic argocd-notifications-secret \
  -n argocd \
  --from-literal=slack-token='xoxb-TU-TOKEN-AQUI' \
  --dry-run=client -o yaml | kubectl apply -f -
```

O edita el archivo manualmente (no commitear el token real):
```yaml
stringData:
  slack-token: "xoxb-1234567890-1234567890123-abcdefghijklmnopqrstuvwx"
```

### 3. Aplicar ConfigMap de Notificaciones

```bash
kubectl apply -f argocd/notifications/argocd-notifications-cm.yaml
```

### 4. Verificar Instalación

```bash
# Ver si el ConfigMap se aplicó
kubectl get configmap argocd-notifications-cm -n argocd

# Ver los logs del controlador de notificaciones
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller -f
```

## Notificaciones Configuradas

### 1. ✅ Aplicación Desplegada (`on-deployed`)
- **Trigger**: Sync exitoso + Health status = Healthy
- **Canal**: #argocdretrogame
- **Color**: Verde (good)
- **Info**: Aplicación, namespace, sync status, health status, revisión

### 2. ❌ Sync Fallido (`on-sync-failed`)
- **Trigger**: Sync fase = Error o Failed
- **Canal**: #argocdretrogame
- **Color**: Rojo (danger)
- **Info**: Aplicación, namespace, fase, mensaje de error

### 3. ⚠️ Aplicación Degradada (`on-health-degraded`)
- **Trigger**: Health status = Degraded
- **Canal**: #argocdretrogame
- **Color**: Amarillo (warning)
- **Info**: Aplicación, namespace, health status, sync status, mensaje

## Personalización

### Cambiar Canal de Notificaciones

Edita la sección `subscriptions` en `argocd-notifications-cm.yaml`:

```yaml
subscriptions: |
  - recipients:
    - slack:NOMBRE_DEL_CANAL  # Cambiar aquí
    triggers:
    - on-deployed
    - on-sync-failed
    - on-health-degraded
```

### Añadir Notificaciones a Aplicaciones Específicas

Añade anotaciones a las aplicaciones en `argocd/apps/*.yaml`:

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.slack: argocdretrogame
    notifications.argoproj.io/subscribe.on-sync-failed.slack: argocdretrogame
    notifications.argoproj.io/subscribe.on-health-degraded.slack: argocdretrogame
```

### Añadir Más Triggers

Triggers disponibles adicionales:
- `on-sync-running`: Cuando inicia un sync
- `on-sync-succeeded`: Cuando termina un sync exitoso (sin validar health)
- `on-health-progressing`: Cuando la app está en Progressing
- `on-health-missing`: Cuando la app está en Missing

## Testing

### Probar Notificación Manual

```bash
# Trigger manual de notificación
argocd app sync backend-app --force
```

### Simular Degraded

```bash
# Escalar a 0 réplicas para trigger health-degraded
kubectl scale deployment backend -n retrogame --replicas=0

# Restaurar
kubectl scale deployment backend -n retrogame --replicas=1
```

### Ver Logs de Notificaciones

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller --tail=50
```

## Troubleshooting

### No llegan notificaciones

1. **Verificar token**:
   ```bash
   kubectl get secret argocd-notifications-secret -n argocd -o jsonpath='{.data.slack-token}' | base64 -d
   ```

2. **Verificar bot en canal**:
   - El bot debe estar invitado al canal `#argocdretrogame`
   - Comando: `/invite @NombreDelBot`

3. **Verificar logs**:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller -f
   ```

4. **Verificar ConfigMap**:
   ```bash
   kubectl get configmap argocd-notifications-cm -n argocd -o yaml
   ```

### Error "channel_not_found"

- El bot no está en el canal o el nombre del canal es incorrecto
- Invitar bot: `/invite @NombreDelBot` en el canal
- Verificar nombre del canal sin `#` en la configuración

### Error "invalid_auth"

- Token incorrecto o expirado
- Verificar que sea un **Bot User OAuth Token** (`xoxb-`)
- Regenerar token en Slack App settings

## Referencias

- [ArgoCD Notifications Docs](https://argocd-notifications.readthedocs.io/)
- [Slack API - Creating Apps](https://api.slack.com/apps)
- [Template Variables](https://argocd-notifications.readthedocs.io/en/stable/templates/)
