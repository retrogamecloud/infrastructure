# Terraform - GitHub Configuration

Configuración de Terraform para gestionar recursos de GitHub en la organización `retrogamecloud`.

## 📋 Recursos Gestionados

Este módulo de Terraform gestiona:

- **Rulesets de repositorios:**
  - Nomenclatura de ramas estándar
  - Protección de rama `main`
  - Protección de tags con Semantic Versioning

- **Labels comunes** en todos los repositorios:
  - `auto` - PR automática generada por workflows
  - `images` - Cambios en imágenes de Docker
  - `documentation` - Mejoras o adiciones a la documentación
  - `enhancement` - Nueva funcionalidad o mejora
  - `bug` - Algo no funciona correctamente

## 🏗️ Estructura

```
.
├── main.tf                  # Configuración principal y provider
├── modules/
│   └── repo-config/        # Módulo reutilizable para configurar repos
│       ├── main.tf         # Recursos (rulesets y labels)
│       └── outputs.tf      # Outputs del módulo
├── .gitignore              # Archivos ignorados por Git
└── README.md               # Este archivo
```

## 🚀 Configuración Inicial

### 1. Prerrequisitos

- Terraform >= 1.0
- Cuenta en [Terraform Cloud](https://app.terraform.io) (gratuita)
- Token de GitHub con permisos de organización

### 2. Autenticación en Terraform Cloud

Crea una cuenta en Terraform Cloud y autentica tu CLI:

```bash
terraform login
```

Esto abrirá tu navegador para crear un token de autenticación de Terraform Cloud.

### 3. Crear Token de GitHub

El provider de GitHub necesita un Personal Access Token con permisos específicos:

1. Ve a https://github.com/settings/tokens
2. Click en **Generate new token** → **Generate new token (classic)**
3. Configuración:
   - **Note:** `terraform-retrogamecloud`
   - **Expiration:** 90 días o Custom
   - **Scopes requeridos:**
     - ✅ `repo` - Full control of private repositories
     - ✅ `admin:org` - Full control of orgs and teams, read and write org projects
     - ✅ `workflow` - Update GitHub Action workflows (opcional)
4. Click **Generate token** y copia el token (empieza con `ghp_` o `github_pat_`)
5. **Guarda este token** - solo se muestra una vez

### 4. Configurar Variables en Terraform Cloud

Ve al workspace: https://app.terraform.io/app/retrogamecloud/workspaces/github-config/variables

**Terraform Variables:**

| Variable | Valor | Sensitive | Descripción |
|----------|-------|-----------|-------------|
| `github_token` | Tu GitHub PAT | ✅ | Token para el provider de GitHub |

**Environment Variables:**

| Variable | Valor | Sensitive | Descripción |
|----------|-------|-----------|-------------|
| `GITHUB_TOKEN` | Tu GitHub PAT | ✅ | Token de GitHub para autenticación |
| `GITHUB_OWNER` | `retrogamecloud` | ❌ | Organización de GitHub |

### 5. Inicializar Terraform

```bash
cd infrastructure/terraform/github
terraform init
```

Si ya tienes un estado local, Terraform te preguntará si quieres migrarlo a Terraform Cloud. Responde `yes` para preservar los recursos importados.

## 📦 Uso

### Ver cambios planeados

```bash
terraform plan
```

### Aplicar cambios

```bash
terraform apply
```

### Ver estado actual

```bash
terraform state list
```

## 🔧 Configuración de Repositorios

Los repositorios gestionados están definidos en `main.tf`:

```hcl
variable "repos" {
  default = ["backend", "frontend", "kubernetes", "docs", "infrastructure", "kong"]
}
```

### Configuración de Status Checks

Algunos repositorios requieren status checks en la rama `main`:

- `backend` ✅
- `frontend` ✅
- `docs` ✅

Para agregar más repositorios con status checks, actualiza en `main.tf`:

```hcl
require_status_checks = contains(["backend", "frontend", "docs", "NUEVO_REPO"], each.key)
```

## 🌐 Backend Remoto

El estado de Terraform se almacena en **Terraform Cloud**:

- **Organización:** `retrogamecloud`
- **Workspace:** `github-config`

### Ventajas del Backend Remoto

✅ **Estado compartido:** Múltiples usuarios pueden trabajar sin conflictos  
✅ **Historial completo:** Registro de todos los cambios aplicados  
✅ **Bloqueo automático:** Previene ejecuciones concurrentes  
✅ **Variables cifradas:** Los tokens se almacenan de forma segura  
✅ **Ejecución remota:** Opcional - ejecutar terraform apply desde la nube  

### Tokens Necesarios

**Dos tokens diferentes son requeridos:**

1. **Token de Terraform Cloud:**
   - Propósito: Autenticar CLI con Terraform Cloud
   - Se crea en: https://app.terraform.io/app/settings/tokens
   - Se configura con: `terraform login`
   - Almacenado en: `~/.terraform.d/credentials.tfrc.json`

2. **Token de GitHub (PAT):**
   - Propósito: Permitir al provider de GitHub gestionar recursos
   - Se crea en: https://github.com/settings/tokens
   - Permisos: `repo`, `admin:org`, `workflow`
   - Se configura como variable en el workspace de Terraform Cloud

## 📝 Variables en Terraform Cloud

Configura estas variables en el workspace de Terraform Cloud:

### Variables de Terraform

| Variable | Tipo | Valor | Sensitive |
|----------|------|-------|-----------|
| `github_token` | Terraform variable | Tu GitHub PAT | ✅ |

### Variables de Entorno

| Variable | Valor | Sensitive |
|----------|-------|-----------|
| `GITHUB_TOKEN` | Tu GitHub PAT | ✅ |
| `GITHUB_OWNER` | `retrogamecloud` | ❌ |

## 🔄 Agregar un Nuevo Repositorio

1. Agrega el nombre del repo a la lista en `main.tf`:
   ```hcl
   variable "repos" {
     default = ["backend", "frontend", ..., "nuevo-repo"]
   }
   ```

2. Si requiere status checks, actualiza:
   ```hcl
   require_status_checks = contains(["backend", "frontend", "docs", "nuevo-repo"], each.key)
   ```

3. Aplica los cambios:
   ```bash
   terraform plan
   terraform apply
   ```

## 🛡️ Rulesets Configurados

### 1. Nomenclatura de Ramas

- **Nombre:** `Nomenclatura ramas - Estándar`
- **Aplica a:** Todas las ramas excepto `main`, `master`, `develop`, `staging`, `production`
- **Estado:** Activo
- **Patrón requerido:** `tipo/descripcion`
  
**Tipos válidos:**
- `feature/` - Nueva funcionalidad
- `bugfix/` - Corrección de errores
- `hotfix/` - Parche urgente para producción
- `release/` - Preparación de nueva versión
- `chore/` - Tareas de mantenimiento
- `docs/` - Documentación
- `refactor/` - Refactorización de código
- `test/` - Añadir o modificar tests
- `ci/` - Cambios en CI/CD

**Ejemplos válidos:**
- ✅ `feature/user-authentication`
- ✅ `bugfix/fix-login-error`
- ✅ `hotfix/security-patch-001`
- ✅ `docs/update-readme`

**Ejemplos inválidos:**
- ❌ `new-feature` (sin tipo/)
- ❌ `feature/User-Auth` (mayúsculas)
- ❌ `feature/user_auth` (guión bajo)
- ❌ `fix-bug` (tipo incorrecto)

**Restricciones aplicadas:**
- ⛔ No se puede crear una rama sin seguir el patrón
- ⛔ Las ramas que no cumplan el patrón serán rechazadas
- ⚠️ Solo se puede eliminar ramas (no se pueden actualizar)
- 👥 Los usuarios con rol "Maintain" o superior pueden hacer bypass

### 2. Protección de Main

- **Nombre:** `Protección rama - Main`
- **Aplica a:** Rama `main` únicamente
- **Estado:** Activo

**Restricciones aplicadas:**
- ⛔ **Requiere Pull Request:** No se pueden hacer commits directos a `main`
- ⛔ **Force Push bloqueado:** No se permite `git push --force`
- ⛔ **Eliminación bloqueada:** La rama `main` no puede ser eliminada
- ⚠️ **Status checks requeridos** (solo en `backend`, `frontend`, `docs`):
  - Debe pasar el check `tests` antes de mergear
  - Debe estar actualizado con la rama base (strict mode)
  - No se requiere en la creación del PR, solo al mergear

**Configuración de Pull Requests:**
- ❌ No requiere revisiones aprobadas (0 reviewers)
- ❌ No se descartan revisiones en nuevos commits
- ❌ No requiere revisión de code owners
- ❌ No requiere aprobación del último push
- ❌ No requiere resolver threads de conversación

**Bypass permitido:**
- 👥 Usuarios con rol de repositorio "Admin" pueden hacer bypass siempre

### 3. Protección de Tags

- **Nombre:** `Protección tag - Semantic Versioning`
- **Aplica a:** Todos los tags (`refs/tags/**`)
- **Estado:** Activo
- **Formato requerido:** Semantic Versioning

**Patrón válido:** `vX.Y.Z[-prerelease][+build]`

**Componentes:**
- `X` = Versión mayor (breaking changes)
- `Y` = Versión menor (nuevas features compatibles)
- `Z` = Patch (bug fixes)
- `-prerelease` = Opcional (alpha, beta, rc.1, etc.)
- `+build` = Opcional (metadata de build)

**Ejemplos válidos:**
- ✅ `v1.0.0` - Release estable
- ✅ `v2.1.3` - Release con features y patches
- ✅ `v1.0.0-alpha` - Pre-release alpha
- ✅ `v1.0.0-beta.2` - Pre-release beta 2
- ✅ `v1.0.0-rc.1` - Release candidate
- ✅ `v1.0.0+build.123` - Con metadata de build
- ✅ `v1.0.0-alpha.1+exp.sha.5114f85` - Completo

**Ejemplos inválidos:**
- ❌ `1.0.0` (sin prefijo `v`)
- ❌ `v1.0` (falta componente patch)
- ❌ `v1` (formato incompleto)
- ❌ `release-1.0.0` (prefijo incorrecto)
- ❌ `version-1.0.0` (formato no válido)

**Restricciones aplicadas:**
- ⛔ **No se pueden eliminar tags:** Los tags son permanentes
- ⛔ **No se pueden actualizar tags:** No se puede hacer `git tag -f`
- ⛔ Tags que no sigan el formato serán rechazados
- 👥 Los usuarios con rol "Admin" pueden hacer bypass siempre

**Buenas prácticas:**
```bash
# Crear un tag anotado con mensaje
git tag -a v1.0.0 -m "Release 1.0.0: Initial stable release"
git push origin v1.0.0

# Para pre-releases
git tag -a v1.1.0-beta.1 -m "Beta 1 de versión 1.1.0"
git push origin v1.1.0-beta.1
```

## 🚨 Troubleshooting

### Error: 404 Not Found

Si recibes errores 404 al ejecutar terraform plan/apply:

**Causa:** El token de GitHub no tiene permisos o no está configurado correctamente en Terraform Cloud.

**Solución:**
1. Verifica que las variables estén configuradas en Terraform Cloud:
   - `github_token` (Terraform variable, sensitive)
   - `GITHUB_TOKEN` (Environment variable, sensitive)
   - `GITHUB_OWNER` = `retrogamecloud` (Environment variable)

2. Verifica que el token de GitHub tenga los permisos correctos:
   ```bash
   # Usa el token para probar acceso
   curl -H "Authorization: token TU_TOKEN_AQUI" https://api.github.com/orgs/retrogamecloud/repos
   ```

### Error: Resource already managed

Si intentas importar un recurso ya gestionado:

```bash
terraform state rm 'module.repos["REPO"].RECURSO'
terraform import 'module.repos["REPO"].RECURSO' 'REPO:ID'
```

### Plan muestra crear recursos que ya existen

**Causa:** El estado en Terraform Cloud está vacío o desincronizado.

**Solución:** Los recursos ya fueron importados en el estado local que se migró. Si ves `Plan: 48 to add`, asegúrate de haber:
1. Migrado el estado local a Terraform Cloud con `terraform init` (responde `yes` cuando pregunte)
2. Configurado las variables en Terraform Cloud antes de hacer plan/apply

## 📚 Recursos Adicionales

- [Terraform GitHub Provider](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [Terraform Cloud Docs](https://developer.hashicorp.com/terraform/cloud-docs)
- [GitHub Rulesets API](https://docs.github.com/en/rest/repos/rules)