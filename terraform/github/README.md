# Terraform - GitHub Configuration

Gestión automatizada de configuración de GitHub para la organización `retrogamecloud` mediante Terraform Cloud.

## 📋 Descripción

Este proyecto utiliza Terraform para gestionar recursos de GitHub de forma centralizada y versionada:

- **Rulesets de protección** en ramas y tags (seguridad, nomenclatura)
- **Labels estándar** en todos los repositorios (organización)
- **Backend remoto** en Terraform Cloud (estado compartido)
- **Multi-repositorio** (backend, frontend, kubernetes, docs, infrastructure, kong)

**Arquitectura:**
```
┌─────────────────────────────────────────┐
│           GitHub Organization           │
│           (retrogamecloud)              │
└────────────────────┬────────────────────┘
                     ↑
                     │ Gestionado por
                     │
┌────────────────────┴────────────────────┐
│   Terraform Cloud                       │
│   └─ Workspace: github-config           │
│   └─ Backend: Estado remoto             │
│   └─ Variables: GitHub Token + Config   │
└─────────────────────────────────────────┘
```

## 🏗️ Estructura de archivos

```
infrastructure/terraform/github/
├── main.tf                 # Provider, variables, repositorios
├── modules/
│   └── repo-config/        # Módulo reutilizable para cada repo
│       ├── main.tf         # Recursos (rulesets y labels)
│       ├── variables.tf    # Variables del módulo
│       └── outputs.tf      # Outputs
├── .gitignore              # Archivos ignorados
├── .terraform.lock.hcl     # Lock de versiones de providers
└── README.md               # Este archivo
```

## 📋 Tabla de contenidos

- [Descripción](#descripción)
- [Estructura de archivos](#estructura-de-archivos)
- [Configuración Inicial](#configuración-inicial)
- [Uso](#uso)
- [Rulesets Configurados](#rulesets-configurados)
- [Repositorios Gestionados](#repositorios-gestionados)
- [Troubleshooting](#troubleshooting)

## 🚀 Configuración Inicial

### Prerequisitos

- **Terraform** >= 1.0
  ```bash
  terraform version
  # Terraform v1.0 o superior
  ```

- **Cuenta en Terraform Cloud** (gratuita)
  - Ir a: https://app.terraform.io
  - Sign up → Create account
  - Crear organización: `retrogamecloud`

- **GitHub Token (Personal Access Token)**
  - Permisos: `repo`, `admin:org`, `workflow`
  - Nunca compartir directamente

### Paso 1: Crear Token de GitHub

1. **Ir a configuración de tokens:**
   ```
   https://github.com/settings/tokens
   ```

2. **Click en "Generate new token" → "Generate new token (classic)"**

3. **Configurar el token:**
   | Campo | Valor |
   |-------|-------|
   | Note | `terraform-retrogamecloud` |
   | Expiration | 90 días |
   | Scopes | ✅ `repo` |
   | | ✅ `admin:org` |
   | | ✅ `workflow` |

4. **Copiar token** (empieza con `ghp_` o `github_pat_`)

5. **GUARDAR en lugar seguro** - Solo se muestra una vez

**Permisos requeridos:**
- `repo` - Full control of private repositories (necesario para rulesets)
- `admin:org` - Full control of orgs and teams (necesario para organización)
- `workflow` - Update GitHub Action workflows (recomendado)

### Paso 2: Autenticarse en Terraform Cloud

```bash
terraform login
```

**Qué hace:**
1. Abre navegador para crear token de Terraform Cloud
2. Ve a: https://app.terraform.io/app/settings/tokens
3. Click **Create an API token**
4. Copia el token en la terminal cuando se pida
5. Se guarda en: `~/.terraform.d/credentials.tfrc.json`

### Paso 3: Configurar Variables en Terraform Cloud

**Acceder al workspace:**
```
https://app.terraform.io/app/retrogamecloud/workspaces/github-config/variables
```

**Agregar variables:**

#### Terraform Variables
```
Variable name: github_token
Value: [Tu GitHub PAT]
Sensitive: ✅ Marcar como sensible
```

#### Environment Variables
```
GITHUB_TOKEN = [Tu GitHub PAT]
Sensitive: ✅

GITHUB_OWNER = retrogamecloud
Sensitive: ❌
```

### Paso 4: Inicializar Terraform

```bash
cd infrastructure/terraform/github

# Inicializar
terraform init

# Si tienes estado local previo, Terraform preguntará:
# "Do you want to copy existing state to the new backend?"
# Responde: yes
```

## 📦 Uso

### Ver configuración planeada

```bash
terraform plan

# Output esperado:
# Plan: 48 to add, 0 to change, 0 to destroy
# (Rulesets, labels para 6 repositorios)
```

### Aplicar cambios

```bash
terraform apply

# Confirmará recursos a crear. Escribir "yes"
# Tiempo estimado: ~30-60 segundos
```

### Verificar estado actual

```bash
# Ver todos los recursos gestionados
terraform state list

# Ver detalles de un recurso específico
terraform state show 'module.repos["backend"].github_repository_ruleset.branch_naming'

# Obtener outputs
terraform output
```

### Agregar un nuevo repositorio

**1. Editar `main.tf`:**
```hcl
variable "repos" {
  default = ["backend", "frontend", "kubernetes", "docs", "infrastructure", "kong", "nuevo-repo"]
}
```

**2. Si requiere status checks, actualizar:**
```hcl
require_status_checks = contains(["backend", "frontend", "docs", "nuevo-repo"], each.key)
```

**3. Aplicar:**
```bash
terraform plan
terraform apply
```

## 🌐 Backend Remoto (Terraform Cloud)

El estado se almacena en **Terraform Cloud**, no localmente:

**Ventajas:**
- ✅ Estado compartido entre usuarios
- ✅ Historial completo de cambios
- ✅ Bloqueo automático (evita conflictos)
- ✅ Variables cifradas (tokens seguros)
- ✅ Ejecución remota opcional

**Workspace en Terraform Cloud:**
```
Organización: retrogamecloud
Workspace: github-config
Backend: S3 (managed by Terraform Cloud)
```

**Dos tokens diferentes necesarios:**

| Token | Propósito | Dónde se crea | Dónde se configura |
|-------|-----------|---------------|--------------------|
| **Terraform Cloud** | Autenticar CLI | https://app.terraform.io/app/settings/tokens | `terraform login` |
| **GitHub (PAT)** | Gestionar recursos de GitHub | https://github.com/settings/tokens | Variables en workspace |

## 🛡️ Rulesets configurados

### 1. Nomenclatura de Ramas

**Propósito:** Estandarizar nombres de ramas (feature/, bugfix/, etc.)

**Configuración:**
- **Nombre:** `Nomenclatura ramas - Estándar`
- **Aplica a:** Todas las ramas excepto `main`, `master`, `develop`, `staging`, `production`
- **Patrón:** `tipo/descripcion` (ej: `feature/user-auth`)
- **Estado:** Activo

**Tipos válidos (prefijos):**
```
feature/  - Nueva funcionalidad
bugfix/   - Corrección de errores
hotfix/   - Parche urgente
release/  - Preparación de versión
chore/    - Tareas de mantenimiento
docs/     - Documentación
refactor/ - Refactorización
test/     - Tests
ci/       - Cambios en CI/CD
```

**Ejemplos válidos:**
```bash
✅ feature/user-authentication
✅ bugfix/fix-login-error
✅ hotfix/security-patch
✅ docs/update-readme
✅ ci/add-github-actions
```

**Ejemplos INVÁLIDOS:**
```bash
❌ new-feature (sin tipo/)
❌ feature/User-Auth (mayúsculas)
❌ feature/user_auth (guión bajo)
❌ fix-bug (tipo incorrecto)
```

**Restricciones aplicadas:**
- ⛔ Imposible crear ramas sin patrón correcto
- ⛔ Imposible hacer push a rama que no cumple patrón
- ⚠️ Solo se pueden eliminar ramas (no actualizar)
- 👥 Admin puede hacer bypass siempre

### 2. Protección de Main

**Propósito:** Evitar cambios directo a `main`, requiere PR

**Configuración:**
- **Nombre:** `Protección rama - Main`
- **Aplica a:** Rama `main` únicamente
- **Estado:** Activo

**Restricciones aplicadas:**
- ⛔ **Requiere Pull Request** - No se pueden hacer commits directos
- ⛔ **Force push bloqueado** - No se permite `git push --force`
- ⛔ **Eliminación bloqueada** - No se puede borrar `main`
- ⚠️ **Status checks** (solo en `backend`, `frontend`, `docs`):
  - Check `tests` debe pasar antes de mergear
  - Rama debe estar actualizado con base (strict mode)

**Configuración de Pull Requests:**
- ❌ NO requiere revisiones aprobadas (0 reviewers)
- ❌ NO descarta revisiones en nuevos commits
- ❌ NO requiere aprobación de code owners

**Bypass permitido:**
- 👥 Usuarios con rol "Admin" del repositorio

### 3. Protección de Tags

**Propósito:** Estandarizar versionado con Semantic Versioning

**Configuración:**
- **Nombre:** `Protección tag - Semantic Versioning`
- **Aplica a:** Todos los tags (`refs/tags/**`)
- **Formato:** Semantic Versioning `vX.Y.Z[-prerelease][+build]`
- **Estado:** Activo

**Componentes:**
```
v{X}.{Y}.{Z}[-prerelease][+build]
  │  │  │       │           │
  │  │  │       │           └─ Metadata de build (opcional)
  │  │  │       └─ Pre-release: alpha, beta, rc.1 (opcional)
  │  │  └─ Patch: bug fixes
  │  └─ Minor: nuevas features compatibles
  └─ Major: breaking changes
```

**Ejemplos válidos:**
```bash
✅ v1.0.0              - Release estable
✅ v2.1.3              - Release con features y patches
✅ v1.0.0-alpha        - Pre-release alpha
✅ v1.0.0-beta.2       - Pre-release beta 2
✅ v1.0.0-rc.1         - Release candidate
✅ v1.0.0+build.123    - Con metadata de build
✅ v1.0.0-alpha.1+exp.sha.5114f85  - Completo
```

**Ejemplos INVÁLIDOS:**
```bash
❌ 1.0.0               - Sin prefijo v
❌ v1.0                - Falta patch
❌ v1                  - Incompleto
❌ release-1.0.0       - Prefijo incorrecto
❌ version-1.0.0       - Formato no válido
```

**Restricciones aplicadas:**
- ⛔ Imposible eliminar tags
- ⛔ Imposible actualizar/reescribir tags (`git tag -f`)
- ⛔ Tags que no sigan formato serán rechazados
- 👥 Admin puede hacer bypass siempre

**Crear tags correctamente:**
```bash
# Release estable
git tag -a v1.0.0 -m "Release 1.0.0: Initial stable release"
git push origin v1.0.0

# Pre-release
git tag -a v1.1.0-beta.1 -m "Beta 1 de versión 1.1.0"
git push origin v1.1.0-beta.1

# Con metadata (para CI)
git tag -a v1.0.0+build.123 -m "Build 123"
git push origin v1.0.0+build.123
```

## 📊 Labels estándar

Aplicados a todos los repositorios:

| Label | Color | Descripción |
|-------|-------|-------------|
| `auto` | 🟦 Azul | PR automática generada por workflows |
| `images` | 🟩 Verde | Cambios en imágenes de Docker |
| `documentation` | 📘 Púrpura | Mejoras o adiciones a documentación |
| `enhancement` | ⭐ Amarillo | Nueva funcionalidad o mejora |
| `bug` | 🔴 Rojo | Algo no funciona correctamente |

## 📚 Repositorios gestionados

### Lista actual

| Repo | Status Checks | Descripción |
|------|---------------|-------------|
| `backend` | ✅ Sí | API REST y lógica de negocio |
| `frontend` | ✅ Sí | Aplicación web cliente |
| `kubernetes` | ❌ No | Manifiestos de Kubernetes |
| `docs` | ✅ Sí | Documentación técnica |
| `infrastructure` | ❌ No | Terraform + infraestructura |
| `kong` | ❌ No | Configuración de Kong API Gateway |

### Status Checks Requeridos

Los repositorios con `require_status_checks = true` requieren que pase el check `tests` antes de mergear a `main`:

**Repos con status checks:**
- ✅ `backend` - Tests de API
- ✅ `frontend` - Tests de componentes
- ✅ `docs` - Validación de markdown

**Repos sin status checks:**
- ❌ `kubernetes` - Manifiestos (validación manual)
- ❌ `infrastructure` - Terraform (validación manual)
- ❌ `kong` - Configuración (validación manual)

## 🔧 Configuración avanzada

### Modificar rulesets

**Archivo:** `modules/repo-config/main.tf`

Tipos de cambios comunes:

**1. Agregar nuevo prefijo de rama:**
```hcl
# En el patrón de nomenclatura
pattern = "^(feature|bugfix|hotfix|release|chore|docs|refactor|test|ci|nuevo-tipo)/.+"
```

**2. Cambiar requisitos de status checks:**
```hcl
require_status_checks = contains(["backend", "frontend", "docs", "nuevo-repo"], each.key)
```

**3. Cambiar reglas de tags:**
```hcl
pattern = "^v[0-9]+\\.[0-9]+\\.[0-9]+.*"  # Para otro formato
```

### Cambiar repositorios gestionados

**Archivo:** `main.tf`

```hcl
variable "repos" {
  default = [
    "backend",
    "frontend",
    "kubernetes",
    "docs",
    "infrastructure",
    "kong",
    # Agregar aquí nuevos repos
  ]
}
```

## 🚨 Troubleshooting

### Error: 404 Not Found

**Síntomas:**
```
Error: GET https://api.github.com/orgs/retrogamecloud: 404 Not Found
```

**Causas posibles:**
- Token de GitHub no configurado en Terraform Cloud
- Token expirado o revocado
- Permisos insuficientes

**Solución:**
```bash
# 1. Verificar que variables están en Terraform Cloud
# https://app.terraform.io/app/retrogamecloud/workspaces/github-config/variables

# Deben estar:
# - github_token (Terraform variable)
# - GITHUB_TOKEN (Environment variable)
# - GITHUB_OWNER = retrogamecloud

# 2. Crear nuevo token si el anterior expiró
# https://github.com/settings/tokens

# 3. Actualizar en Terraform Cloud
```

### Error: Resource already managed

**Síntomas:**
```
Error: Resource already exists
```

**Causa:** Intentar importar un recurso ya gestionado

**Solución:**
```bash
# Ver estado actual
terraform state list

# Remover si es duplicado
terraform state rm 'module.repos["backend"].github_repository_ruleset.branch_naming'

# Re-importar si es necesario
terraform import 'module.repos["backend"].github_repository_ruleset.branch_naming' 'backend:ruleset_id'
```

### Error: Failed to read configuration from disk

**Síntomas:**
```
Error: Failed to read configuration from disk
```

**Causa:** Archivo `.terraform.lock.hcl` corrupto o versión de provider incompatible

**Solución:**
```bash
# Reinicializar terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Plan muestra crear recursos que ya existen

**Síntomas:**
```
Plan: 48 to add, 0 to change, 0 to destroy
```

**Pero no se ve cambio real:**

**Causa:** Estado no migrado de local a Terraform Cloud

**Solución:**
```bash
# En init, responder YES a pregunta de migración
terraform init
# → Preguntrá: "Do you want to copy existing state to new backend?"
# Responder: yes
```

### Ramas no siguen nomenclatura

**Síntomas:**
```
Cannot create or update ref refs/heads/my-feature
Ruleset Violation: Ref name does not conform to pattern
```

**Causa:** Nombre de rama no sigue patrón `tipo/descripcion`

**Solución:**
```bash
# Crear rama con formato correcto
git checkout -b feature/my-new-feature

# Si ya existe rama mal nombrada, renombrarla
git branch -m old-name feature/new-name
git push origin :old-name origin feature/new-name
```

### No puedo mergear a main

**Síntomas:**
```
Merge blocked by ruleset
Status checks required
```

**Causa:** Status check no pasó o rama no actualizada

**Solución:**
```bash
# 1. Verificar checks en GitHub Actions
# https://github.com/retrogamecloud/[repo]/actions

# 2. Actualizar rama con main
git fetch origin
git rebase origin/main

# 3. Hacer push y esperar a que pasen checks
git push origin feature/my-feature
```

## 📚 Recursos adicionales

- [Terraform GitHub Provider](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [Terraform Cloud Docs](https://developer.hashicorp.com/terraform/cloud-docs)
- [GitHub Rulesets API](https://docs.github.com/en/rest/repos/rules)
- [Semantic Versioning](https://semver.org/)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository)
