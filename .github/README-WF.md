# Workflows CI/CD - Infrastructure

Este documento describe los workflows ubicados en `.github/workflows` del repositorio infrastructure: `validate-and-scan.yml`. Incluye descripción funcional, condiciones de ejecución, variables/secrets utilizados, estructura de jobs y ejemplos prácticos para ejecución manual. Este workflow está diseñado para validar y asegurar la calidad, seguridad y conformidad de las configuraciones de infraestructura (Terraform, ArgoCD, manifiestos Kubernetes) antes de ser aplicadas en producción.

## 📑 Índice

1. **[validate-and-scan.yml](#validate-and-scanyml)**
   - [Descripción del workflow](#descripción-del-workflow)
   - [Triggers y condiciones de ejecución](#triggers-y-condiciones-de-ejecución)
   - [Variables de entorno](#variables-de-entorno-env)
   - [Secrets requeridos](#secrets-requeridos)
   - [Estructura de jobs](#estructura-de-jobs-paso-a-paso)
   - [Ejemplos de ejecución manual](#ejemplos-de-ejecución-manual-workflow_dispatch)
   - [Validaciones y seguridad](#validaciones-y-seguridad)
   - [Comportamiento ante fallos](#comportamiento-ante-fallos)

2. **[dependabot.yml](#dependabotyml)**
   - [Descripción del workflow](#descripción-del-workflow-1)
   - [Triggers y condiciones de ejecución](#triggers-y-condiciones-de-ejecución-1)
   - [Estructura y flujo paso a paso](#estructura-y-flujo-paso-a-paso)
   - [Límites y políticas](#límites-y-políticas)
   - [Ejemplos de ejecución automática](#ejemplos-de-ejecución-automática)
   - [Validaciones y seguridad](#validaciones-y-seguridad-1)
   - [Comportamiento ante fallos](#comportamiento-ante-fallos-1)
   - [Recomendaciones operativas](#recomendaciones-operativas)

3. **[Notas operativas](#notas-operativas)**

4. **[Guía de troubleshooting](#guía-de-troubleshooting)**
   - [validate-and-scan.yml - Problemas más comunes](#validate-and-scanyml---problemas-más-comunes)
   - [dependabot.yml - Problemas más comunes](#dependabotyml---problemas-más-comunes)

5. **[Tabla de referencia](#tabla-de-referencia-workflows-y-triggers)**
   - [Tabla de workflows y triggers](#tabla-de-referencia-workflows-y-triggers)
   - [Tabla de variables de entorno](#tabla-de-variables-de-entorno)
   - [Tabla de secrets requeridos](#tabla-de-secrets-requeridos)

---

## validate-and-scan.yml

### Descripción del workflow
Archivo: [.github/workflows/validate-and-scan.yml](https://github.com/retrogamecloud/infrastructure/blob/main/.github/workflows/validate-and-scan.yml)

- **Validación multi-capa:** ejecuta linting, validación de Terraform, validación de ArgoCD, análisis de seguridad y notificaciones de fallos.
- **Infraestructura como Código (IaC):** Terraform fmt check, init y validate en todos los directorios de infraestructura.
- **Validación de manifiestos:** ArgoCD YAML encontrados y validados para conformidad con estándares GitOps.
- **Análisis de seguridad:** SonarCloud para análisis estático + Snyk IaC scan (deshabilitado por defecto en infrastructure) con reporte SARIF a GitHub Security.
- **Notificaciones:** Slack para fallos críticos en Terraform o SonarCloud (si habilitado).
- **Características especiales:** Jobs de validación con `continue-on-error: true` permiten que pipeline continúe para recopilación de resultados; fallará al final si hay problemas críticos.

### Triggers y condiciones de ejecución

| Trigger | Rama | Condición | Descripción |
|---------|------|-----------|-------------|
| `push` | `main` | Excepto cambios en `**.md` y `.gitignore` | Se ejecuta al hacer push a main con cambios en infraestructura |
| `pull_request` | `main` | Excepto cambios en `**.md` y `.gitignore` | Se ejecuta en PRs contra main para validación previa a merge |
| `workflow_dispatch` | Cualquiera | Manual | Permite ejecución manual desde "Actions" tab en GitHub |

**Paths ignore:**
- `**.md` - No ejecutar si solo hay cambios en markdown
- `.gitignore` - No ejecutar si solo hay cambios en .gitignore

**Concurrency:**
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
Una sola ejecución del workflow por rama; cancela ejecuciones anteriores en progreso para la misma rama.

### Variables de entorno (env)

```yaml
env:
  ENABLE_SNYK: false                    # Snyk IaC scanning deshabilitado por defecto
  ENABLE_SLACK_NOTIFICATIONS: true      # Notificaciones Slack habilitadas
```

| Variable | Valor por defecto | Propósito | Modificable |
|----------|-------------------|----------|------------|
| `ENABLE_SNYK` | `false` | Habilita/inhabilita escaneo Snyk IaC (infraestructura) | Sí (env) |
| `ENABLE_SLACK_NOTIFICATIONS` | `true` | Habilita/inhabilita notificaciones Slack en fallos | Sí (env) |

### Secrets requeridos

```yaml
permissions:
  contents: read
  security-events: write
```

| Secret | Requerido | Propósito | Scope |
|--------|-----------|----------|-------|
| `GITHUB_TOKEN` | Sí (automático) | Acceso GitHub, lectura de repo, reportes de seguridad | Global |
| `SONAR_TOKEN` | Condicional | SonarCloud quality scan para infrastructure | `sonarcloud-scan` |
| `SNYK_TOKEN` | Condicional | Snyk vulnerability scan IaC (solo si ENABLE_SNYK=true) | `snyk-scan` |
| `SLACK_WEBHOOK_URL` | Condicional | Webhook Slack para notificaciones en fallos | `notify-slack` |

### Estructura de jobs (paso a paso)

#### 1. `lint-infrastructure` (no-bloqueante)
- Clonar repo, setup Node.js 20 con caché npm.
- Ejecuta `npm test` si existe.
- Resume resultados en `$GITHUB_STEP_SUMMARY`; no bloquea pipeline.
- `continue-on-error: true` → workflow continúa aunque haya errores.

#### 2. `validate-terraform` (crítico)
- Setup Terraform (última versión).
- Busca todos los directorios con archivos `.tf`.
- Para cada directorio:
  - `terraform fmt -check -recursive` → verifica formato.
  - `terraform init -backend=false` → inicializa sin backend remoto.
  - `terraform validate` → valida sintaxis (omite si dependencias externas).
- Falla si problemas en fmt, init o validate.

#### 3. `validate-argocd` (no-bloqueante)
- Busca archivos YAML en directorios `argocd/`.
- Si existen → ✅; si no → ⚠️.
- `continue-on-error: true` → validación no crítica.

#### 4. `sonarcloud-scan` (no-bloqueante)
- Clona con `fetch-depth: 0` (historial completo).
- Ejecuta SonarCloud scan:
  - Proyecto: `retrogamecloud_<repository-name>`.
  - Organización: `retrogamecloud`.
  - Sources: `terraform`, `argocd`, `monitoring`.
  - Exclusiones: `**/*.tfstate`, `**/*.tfstate.backup`, `**/node_modules/**`, `**/.terraform/**`.
- Si `SONAR_TOKEN` vacío → warning.
- Si scan falla → error (pero `continue-on-error: true`).

#### 5. `snyk-scan` (no-bloqueante)
- Clona repositorio.
- Si repo público Y `ENABLE_SNYK == 'true'`:
  - Ejecuta `snyk/actions/iac@master`.
  - Genera SARIF y JSON output.
  - Si SARIF existe, sube a GitHub Security.
- Si repo privado O `ENABLE_SNYK == 'false'`:
  - Omite Snyk (message informativo).
- `continue-on-error: true` → fallos no detienen pipeline.

#### 6. `notify-slack` (condicional)
- Ejecuta si: `always()` Y (`validate-terraform` falla O `sonarcloud-scan` falla).
- Si `ENABLE_SLACK_NOTIFICATIONS == 'true'`:
  - Construye mensaje JSON con repos, rama, jobs fallidos, link a workflow.
  - POST a `SLACK_WEBHOOK_URL`.
- Falla silenciosamente si webhook inválido.

### Ejemplos de ejecución manual (`workflow_dispatch`)

#### Ejemplo 1: Validar cambios en rama feature
```
Rama: feature/terraform-refactor
→ Resultado:
  - Lint: OK (avisos solo)
  - Terraform fmt: OK
  - Terraform init: OK
  - Terraform validate: OK
  - ArgoCD: ✅ archivos encontrados
  - SonarCloud: OK
  - Snyk: Omitido (ENABLE_SNYK=false)
  - Slack: Silencio (todo OK)
→ Acción: Merge a main sin bloqueos
```

#### Ejemplo 2: Error en formato Terraform
```
Rama: feature/new-resources
→ Resultado:
  - Terraform fmt: ⚠️ "formatting errors"
  - Terraform init: BLOQUEADO
  - Slack: Notifica fallo de Terraform
→ Acción: Ejecutar `terraform fmt -recursive terraform/` localmente, commit fix, push
```

#### Ejemplo 3: SonarCloud detecta código smell
```
Rama: main (push con cambios)
→ Resultado:
  - Terraform validate: OK
  - SonarCloud: ⚠️ "Code smells detectados"
  - Snyk: OK (deshabilitado)
  - Slack: Notifica fallo de SonarCloud
→ Acción: Revisar SonarCloud dashboard, corregir issues, push nuevo commit
```

### Validaciones y seguridad
  - **Lint/ArgoCD:** no bloqueantes; resumidas pero permiten continuación.
  - **Terraform gate:** crítico; fmt, init y validate deben pasar.
  - **SonarCloud:** información; no bloquea pero se reporta en Slack.
  - **Snyk IaC:** deshabilitado por defecto (ENABLE_SNYK=false); puede habilitarse.
  - **Permisos:** lectura global; `security-events: write` solo en Snyk para SARIF upload.
  - **Exclusiones:** `.tfstate`, dependencias externas y `node_modules` excluidos de análisis.

### Comportamiento ante fallos
  - **Lint falla:** aviso, workflow continúa (continue-on-error).
  - **Terraform falla:** workflow detiene (crítico).
  - **ArgoCD falla:** aviso, workflow continúa (no-bloqueante).
  - **SonarCloud falla:** registra error, notifica Slack, pero continúa (continue-on-error).
  - **Snyk falla:** omitido por defecto; si habilitado, no bloquea (continue-on-error).
  - **Slack webhook inválido:** falla silenciosamente, no impacta validación.

---

## dependabot.yml

### Descripción del workflow

Archivo: [.github/dependabot.yml](https://github.com/retrogamecloud/infrastructure/blob/main/.github/dependabot.yml)

- **Dependencia automática updates:** Detecta nuevas versiones de GitHub Actions y crea PRs automáticamente
- **Escaneo diario:** Por defecto, ejecuta cada día a una hora fija (determinada por GitHub)
- **Agrupación:** Todos los updates de actions se agrupan en una única PR
- **Límite de PRs:** Máximo 5 PRs abiertas simultáneamente
- **Asignados:** evaristogz, naesman1, jpalenz77
- **Prefijo de commit:** `ci` scope (ej: "ci: update actions")
- **Scope:** GitHub Actions únicamente (no npm, Docker, Terraform)

### Triggers y condiciones de ejecución

| Trigger | Frecuencia | Rama | Descripción |
|---------|-----------|------|-------------|
| `schedule` | Diario | Cualquiera | Ejecuta automáticamente cada día a hora determinada por GitHub |
| Manual (GitHub) | N/A | main | Puede ejecutarse manual desde Dependabot settings si es necesario |

**Horario:** GitHub ejecuta entre 00:00-05:00 UTC (aproximadamente); hora exacta varía según carga

**Rama por defecto:** Dependabot crea PRs contra `main` automáticamente

### Estructura y flujo paso a paso

**Flujo de Dependabot (automático, sin jobs):**

1. **Scan diario** (00:00-05:00 UTC):
   - Dependabot busca nuevas versiones de GitHub Actions
   - Compara versiones pinneadas en `.github/workflows/` vs disponibles
   - Identifica updates no-major, minor, patch según configuración

2. **Grouping aplicado** (`groups.actions-all`):
   - Patrón `*` combina TODOS los updates de actions en una sola PR
   - Sin grouping, cada action tendría su propia PR (innecesario)

3. **PR Creation:**
   - Rama: `dependabot/github_actions/main-<hash>`
   - Commits: Prefijo `ci`, incluye scope (`ci(deps): update actions`)
   - Asignados: evaristogz, naesman1, jpalenz77
   - Labels: `dependencies`, `github_actions`

4. **CI Execution:**
   - GitHub automáticamente ejecuta workflow `validate-and-scan.yml` en rama Dependabot
   - Tests, validación de Terraform, Snyk scans se ejecutan
   - Si pasan: ✅ PR verde, listo para merge
   - Si fallan: ❌ PR rojo, requiere fix manual

5. **PR Management:**
   - Dependabot puede auto-merge si configurado (no en este caso)
   - Manual merge requerido
   - Después de merge, próxima PR en próximo scan diario

6. **Límites:**
   - `open-pull-requests-limit: 5` - máx 5 PRs abiertas
   - Si límite alcanzado, Dependabot espera hasta que PRs se cierren/mergeen
   - No hay pulsión de más PRs hasta bajar de 5

### Límites y políticas

| Límite | Valor | Descripción |
|--------|-------|-------------|
| `open-pull-requests-limit` | 5 | Máximo 5 PRs de Dependabot abiertas simultáneamente |
| `schedule.interval` | `daily` | Escaneo cada 24 horas |
| `package-ecosystem` | `github-actions` | Solo GitHub Actions, sin npm/Terraform/etc |
| Asignados | 3 personas | evaristogz, naesman1, jpalenz77 |

**Política de versiones:**
- Por defecto: Permite todas las versiones (major, minor, patch)
- No hay restricciones configuradas en YAML

### Validaciones y seguridad

**Validaciones en PRs de Dependabot:**

| Validación | Ejecutor | Resultado en PR |
|-----------|----------|-----------------|
| `lint-infrastructure` | GitHub Actions (workflow) | ✅/⚠️ (no bloqueante) |
| `validate-terraform` | GitHub Actions (workflow) | ✅/❌ (bloqueante si falla) |
| `validate-argocd` | GitHub Actions (workflow) | ✅/⚠️ (no bloqueante) |
| `sonarcloud-scan` | GitHub Actions (workflow) | ✅/⚠️ (info) |
| `snyk-scan` | GitHub Actions (workflow) | ✅ (deshabilitado) |

**Seguridad:**

- **Scope restringido:** Solo `github-actions`, no npm/Dockerfile/Terraform
- **Permisos:** Usa `GITHUB_TOKEN` automático, sin secretos adicionales
- **Revisión:** Manual merge requerido (no auto-merge)
- **CI required:** Cambios validados por `validate-and-scan.yml` antes de merge
- **Audit trail:** Todos los cambios trackeados en git, asignable a persona específica

### Comportamiento ante fallos

| Escenario | Acción Dependabot | Resultado |
|-----------|------------------|-----------|
| PR de Dependabot falla tests | Permanece abierta, marcada ❌ | Manual review requerido para merge |
| PR de Dependabot falla Terraform | No puede mergearse, bloqueada | Requiere fix (generalmente no sucede, action stable) |
| Múltiples PRs necesarias pero límite alcanzado | Espera | Automático resume cuando hay cuota |
| Action nueva release major | No crea PR automática | Requiere manual intervention (seguridad) |
| Dependabot sin permisos en repo | PR no se crea | Requiere verificar configuración |

**Recuperación ante fallos:**

1. **PR de Dependabot con tests fallidos:**
   ```bash
   # Checkout rama Dependabot
   git fetch origin dependabot/github_actions/main-<hash>
   git checkout dependabot/github_actions/main-<hash>
   # Validar localmente
   terraform validate terraform/*
   # Si OK, push y re-ejecuta workflow
   # Si Dependabot creó issue, Dependabot puede auto-fix
   ```

2. **Límite de 5 PRs alcanzado:**
   - Nada que hacer; es automático
   - Mergea PRs existentes
   - Dependabot automáticamente continúa cuando hay espacio

3. **Quitar/reasignar asignados:**
   - Editar `.github/dependabot.yml`
   - Cambiar `assignees` list
   - Dependabot utiliza configuración para nuevas PRs

### Recomendaciones operativas

1. **Revisión de PRs de Dependabot:**
   - Reviewear changelog de action actualizada
   - Verificar que CI pasa (✅ todos los checks)
   - Mergear con confianza si cambios son compatibles

2. **Mantener limit manageable:**
   - Mergea PRs regularmente (1-2 por semana)
   - No acumules PRs abiertas
   - Si 5 abiertas, prioriza merging

3. **Monitoreo:**
   - Revisar email notifications de Dependabot
   - Si PRs con fallos, investigar por qué action causó issue
   - Reportar bugs a action maintainers si es necesario

4. **Major version updates:**
   - Dependabot NO crea PR para major versions automáticamente
   - Para major updates, actualizar manualmente en workflow YAML
   - Test localmente antes de commit

---

## Notas operativas

### Ejecución automática vs manual

**Automática (sin intervención):**
- Push a `main` con cambios en infraestructura → `validate-and-scan.yml` ejecuta
- PR hacia `main` → `validate-and-scan.yml` ejecuta
- Dependabot scan diario → PR creada automáticamente si updates disponibles

**Manual (desde GitHub Actions UI):**
- Seleccionar workflow > "Run workflow" > rama > "Run workflow"
- Útil para debugging o forzar validación sin cambios

### Monitoreo y alertas

- **Slack:** Solo notificaciones en fallos (Terraform o SonarCloud)
- **GitHub:** Status checks en PRs muestran estado de cada job
- **Email:** Dependabot notificaciones si PR abierta/cerrada
- **SonarCloud:** Dashboard para quality metrics

### Mejores prácticas

1. **Validar localmente antes de push:**
   ```bash
   terraform fmt -recursive terraform/
   terraform validate terraform/*
   npm test
   ```

2. **Revisar Dependabot PRs:**
   - Leer changelog de actions actualizadas
   - Verificar CI verde antes de merge
   - Mergear regularmente para evitar acumulación

3. **Mantener secrets actualizados:**
   - SONAR_TOKEN, SNYK_TOKEN, SLACK_WEBHOOK_URL
   - Renovar anualmente
   - Validar que siguen funcionando

4. **Monitoreo de fallos:**
   - Si `validate-terraform` falla, debugg localmente
   - Si `sonarcloud-scan` falla, revisar SonarCloud dashboard
   - Si Snyk habilitado, revisar `snyk-iac.json` para vulnerabilidades

---

## Guía de troubleshooting

### `validate-and-scan.yml` - Problemas más comunes

| Problema | Causa Probable | Solución |
|----------|----------------|----------|
| Terraform validate falla: "Error: Module not found" | Directorio terraform contiene referencias a módulos no inicializados | Ejecutar `terraform init -backend=false` en directorio específico; revisar source de módulo |
| Terraform fmt error: "formatting errors" | Archivos `.tf` no están formateados correctamente | Ejecutar `terraform fmt -recursive terraform/` localmente; commit y push |
| Workflow no ejecuta en PR | Path ignore coincide (solo cambios en `.md` o `.gitignore`) | Verifica si realmente hay cambios en infraestructura; si todo es markdown, es normal que no ejecute |
| SonarCloud scan sin resultados | SONAR_TOKEN no configurado o inválido | Verificar secret en GitHub repo settings; regenerar token en SonarCloud si es necesario |
| Snyk falla (si ENABLE_SNYK=true) | SNYK_TOKEN inválido o repo privado | En repo público, verificar secret; en privado, Snyk salta por default |
| Notificación Slack no llega | SLACK_WEBHOOK_URL inválido o Slack deshabilitado | Verificar secret; si ENABLE_SLACK_NOTIFICATIONS=false, deshabilita notificaciones |

### `dependabot.yml` - Problemas más comunes

| Problema | Causa Probable | Solución |
|----------|----------------|----------|
| PR de Dependabot no se crea | Scan aún no ejecutado o límite de 5 PRs alcanzado | Esperar próximo scan; mergear PRs existentes si límite alcanzado |
| PR de Dependabot falla tests | Action actualizada incompatible con workflow | Revisar PR, ver qué action falló; actualizar workflow si es necesario, commit fix en rama |
| Múltiples PRs en lugar de una agrupada | `groups.actions-all` no funciona (typo en YAML) | Verificar sintaxis de `dependabot.yml`; patrón debe ser exactamente `*` |
| Dependabot PRs no asignadas a personas esperadas | Asignados en config incorrecto o no tiene permisos | Editar `assignees` en `dependabot.yml`; verificar que usuarios existen en org |

---

## Tabla de referencia: workflows y triggers

| Workflow | Triggers | Manual Input | Tiempo Típico | Destino Salida | Concurrency |
|----------|----------|--------------|---------------|-----------------|-------------|
| `validate-and-scan.yml` | push `main`, PR, `workflow_dispatch` | N/A | 10-15 min | GitHub Actions summary, SonarCloud, Slack (si falla) | `cancel-in-progress: true` |
| `dependabot.yml` | `schedule` (diario) | Automático | N/A | PR en infrastructure repo | N/A |

## Tabla de variables de entorno

| Variable | Valor | Propósito | Modificable |
|----------|-------|----------|------------|
| `ENABLE_SNYK` | `false` | Habilita/inhabilita escaneo Snyk IaC (infraestructura) | Sí (env) |
| `ENABLE_SLACK_NOTIFICATIONS` | `true` | Habilita/inhabilita notificaciones Slack | Sí (env) |

## Tabla de secrets requeridos

| Secret | Requerido | Propósito | Scope |
|--------|-----------|----------|-------|
| `GITHUB_TOKEN` | Sí (automático) | Acceso GitHub, lectura repo, reportes seguridad | Global |
| `SONAR_TOKEN` | Condicional | SonarCloud quality scan | `sonarcloud-scan` |
| `SNYK_TOKEN` | Condicional | Snyk IaC vulnerability scan (solo si ENABLE_SNYK=true) | `snyk-scan` |
| `SLACK_WEBHOOK_URL` | Condicional | Webhook Slack para notificaciones | `notify-slack` |

---
