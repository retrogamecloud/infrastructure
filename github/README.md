# 🔧 GitHub Configuration Management - RetroGameCloud

Este directorio contiene configuraciones reutilizables para gestionar repositorios de GitHub mediante el CLI `gh`.

## 📁 Contenido

### Rulesets
- `ruleset-nombre-rama.json` - Nomenclatura estándar para ramas
- `ruleset-proteccion-rama.json` - Protección para rama main
- `ruleset-proteccion-tag.json` - Protección para tags

### Labels
- `labels.json` - Definición de labels estándar

---

## 🏷️ Gestión de Labels

### Estructura del archivo `labels.json`

```json
[
  {
    "name": "nombre-label",
    "description": "Descripción del label",
    "color": "HEX_COLOR"
  }
]
```

### Aplicar labels con GitHub CLI

#### Requisitos previos

1. **Instalar GitHub CLI**:
   ```bash
   # Windows (winget)
   winget install GitHub.cli
   
   # Linux
   sudo apt install gh
   
   # macOS
   brew install gh
   ```

2. **Autenticarse**:
   ```bash
   gh auth login
   ```

3. **Instalar jq** (procesador JSON):
   ```bash
   # Windows (winget)
   winget install jqlang.jq
   
   # Linux
   sudo apt install jq
   
   # macOS
   brew install jq
   ```

#### Aplicar a todos los repositorios

```bash
cd infrastructure/github

for repo in backend docs frontend infrastructure kong kubernetes; do
  echo "📦 Procesando repositorio: retrogamecloud/$repo"
  
  cat labels.json | jq -c '.[]' | while IFS= read -r label; do
    NAME=$(echo "$label" | jq -r '.name')
    DESCRIPTION=$(echo "$label" | jq -r '.description')
    COLOR=$(echo "$label" | jq -r '.color')
    
    # Verificar si el label ya existe
    if gh label list --repo "retrogamecloud/$repo" --limit 1000 | grep -q "^${NAME}"; then
      # Actualizar label existente
      gh label edit "$NAME" --repo "retrogamecloud/$repo" \
        --description "$DESCRIPTION" --color "$COLOR" 2>/dev/null \
        && echo "  ✅ Actualizado: $NAME" || echo "  ❌ Error: $NAME"
    else
      # Crear label nuevo
      gh label create "$NAME" --repo "retrogamecloud/$repo" \
        --description "$DESCRIPTION" --color "$COLOR" 2>/dev/null \
        && echo "  ✅ Creado: $NAME" || echo "  ❌ Error: $NAME"
    fi
  done
  
  echo ""
done

echo "✅ Proceso completado"
```

### Labels disponibles

- `auto` - Creado automáticamente por un workflow
- `rollback` - Cambios de rollback
- `urgent` - Acción prioritaria
- `images` - Cambios en imágenes de Docker

### Personalización de labels

Para añadir o modificar labels:

1. Edita `labels.json`
2. Ejecuta el script con `--dry-run` para verificar
3. Aplica los cambios sin dry-run

```bash
# Verificar cambios
./apply-labels.sh retrogamecloud/backend --dry-run

# Aplicar
./apply-labels.sh retrogamecloud/backend
```

---

## 📋 Rulesets Disponibles

### 1️⃣ Nomenclatura de Ramas (`ruleset-nombre-rama.json`)

**Propósito:** Obliga a usar prefijos estándar para nombres de ramas.

**Formato requerido:** `tipo/descripción`
### Personalización de labels

Para añadir o modificar labels, edita `labels.json` y vuelve a ejecutar el comando for anterior. Ejemplos válidos:**
```bash
git checkout -b feature/user-authentication
git checkout -b bugfix/fix-login-error
git checkout -b hotfix/security-patch
git checkout -b release/v1.2.0
git checkout -b chore/update-dependencies
git checkout -b docs/api-reference
git checkout -b refactor/database-layer
git checkout -b test/integration-tests
git checkout -b ci/add-snyk-scan
```

**❌ Ejemplos inválidos:**
```bash
git checkout -b my-feature              # Sin prefijo tipo/
git checkout -b Feature/new-thing       # Mayúsculas
git checkout -b feature/My_Feature      # Mayúsculas y underscores
git checkout -b feat/something          # Debe ser "feature/"
```

**Reglas:**
- Solo minúsculas: `a-z`
- Solo números: `0-9`
- Solo guiones: `-`
- Sin espacios, underscores ni caracteres especiales

---

### 2️⃣ Protección de Rama Main (`ruleset-proteccion-rama.json`)

**Propósito:** Protege la rama `main` contra cambios no autorizados.

**Protecciones activas:**

✅ **Pull Request requerido** (aunque sin aprobaciones obligatorias)
✅ **Status checks obligatorios:**
  - Debe pasar el job `tests` antes de hacer merge
  - Branch debe estar actualizado con `main`
✅ **Previene eliminación de la rama**
✅ **Previene force push** (no se permite reescribir el historial)

**Workflow de trabajo:**
```bash
# 1. Crear rama de trabajo
git checkout -b feature/my-feature

# 2. Hacer cambios y commits
git add .
git commit -m "feat: add new feature"

# 3. Push a GitHub
git push origin feature/my-feature

# 4. Crear Pull Request
gh pr create --title "feat: Add new feature"

# 5. Esperar que pasen los tests ✅

# 6. Hacer merge (manual o automático)
```

---

### 3️⃣ Protección de Tags (`ruleset-proteccion-tag.json`)

**Propósito:** Obliga a usar Semantic Versioning para tags y los protege.

**Formato requerido:** `vX.Y.Z`

Donde:
- `X` = MAJOR version (cambios incompatibles)
- `Y` = MINOR version (nuevas funcionalidades compatibles)
- `Z` = PATCH version (correcciones de bugs)

**✅ Ejemplos válidos:**
```bash
git tag v1.0.0          # Release estable
git tag v2.1.3          # Release con parches
git tag v1.0.0-alpha    # Pre-release alpha
git tag v1.0.0-beta.1   # Pre-release beta
git tag v1.0.0-rc.2     # Release candidate
git tag v1.0.0+20251121 # Con metadata de build
```

**❌ Ejemplos inválidos:**
```bash
git tag v1              # Incompleto
git tag 1.0.0           # Sin 'v' inicial
git tag release         # Nombre arbitrario
git tag v1.0            # Falta PATCH
```

**Protecciones activas:**
✅ **Solo permite tags con formato Semantic Versioning**
✅ **Previene eliminación de tags**
✅ **Previene modificación de tags existentes**

**Cómo crear un tag:**
```bash
# Asegúrate de estar en main y actualizado
git checkout main
git pull origin main

# Crear el tag con anotación
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release"

# Push del tag a GitHub
git push origin v1.0.0

# Esto disparará automáticamente el workflow de CI/CD
# y creará la imagen Docker con el tag v1.0.0
```

---

## 🚀 Aplicar Rulesets

### Opción 1: Aplicar a un repositorio específico

```bash
cd infrastructure/github

# Nomenclatura de ramas
gh api repos/retrogamecloud/REPO_NAME/rulesets \
  --method POST \
  --input ruleset-nombre-rama.json

# Protección de rama main
gh api repos/retrogamecloud/REPO_NAME/rulesets \
  --method POST \
  --input ruleset-proteccion-rama.json

# Protección de tags
gh api repos/retrogamecloud/REPO_NAME/rulesets \
  --method POST \
  --input ruleset-proteccion-tag.json
```

### Opción 2: Aplicar a todos los repositorios

```bash
cd infrastructure/github

for repo in backend frontend infrastructure kong kubernetes; do
  echo "Aplicando rulesets a $repo..."
  
  gh api repos/retrogamecloud/$repo/rulesets \
    --method POST \
    --input ruleset-nombre-rama.json
  
  gh api repos/retrogamecloud/$repo/rulesets \
    --method POST \
    --input ruleset-proteccion-rama.json
  
  gh api repos/retrogamecloud/$repo/rulesets \
    --method POST \
    --input ruleset-proteccion-tag.json
  
  echo "✅ Rulesets aplicados a $repo"
done
```

### Opción 3: Actualizar rulesets existentes

```bash
cd infrastructure/github

for repo in backend frontend infrastructure kong kubernetes; do
  echo "=== Actualizando rulesets en $repo ==="
  
  # Obtener IDs de los rulesets
  NOMENCLATURA_ID=$(gh api repos/retrogamecloud/$repo/rulesets \
    --jq '.[] | select(.name=="Nomenclatura ramas - Estándar") | .id')
  
  PROTECCION_RAMA_ID=$(gh api repos/retrogamecloud/$repo/rulesets \
    --jq '.[] | select(.name=="Protección rama - Main") | .id')
  
  PROTECCION_TAG_ID=$(gh api repos/retrogamecloud/$repo/rulesets \
    --jq '.[] | select(.name=="Protección tag - Semantic Versioning") | .id')
  
  # Actualizar si existen
  [ -n "$NOMENCLATURA_ID" ] && \
    gh api repos/retrogamecloud/$repo/rulesets/$NOMENCLATURA_ID \
      --method PUT --input ruleset-nombre-rama.json
  
  [ -n "$PROTECCION_RAMA_ID" ] && \
    gh api repos/retrogamecloud/$repo/rulesets/$PROTECCION_RAMA_ID \
      --method PUT --input ruleset-proteccion-rama.json
  
  [ -n "$PROTECCION_TAG_ID" ] && \
    gh api repos/retrogamecloud/$repo/rulesets/$PROTECCION_TAG_ID \
      --method PUT --input ruleset-proteccion-tag.json
  
  echo "✅ Rulesets actualizados en $repo"
done
```

---

## 📊 Ver Rulesets Aplicados

```bash
# Listar rulesets de un repositorio
gh api repos/retrogamecloud/backend/rulesets \
  --jq '.[] | "\(.id) - \(.name) (\(.enforcement))"'

# Ver detalles de un ruleset específico
gh api repos/retrogamecloud/backend/rulesets/RULESET_ID
```

---

## 🔧 Personalización

### Cambiar número de aprobaciones requeridas

Edita `ruleset-proteccion-rama.json`:
```json
"required_approving_review_count": 1  // Cambiar de 0 a 1+
```

### Añadir nuevos prefijos de rama

Edita `ruleset-nombre-rama.json`, en el patrón regex:
```json
"pattern": "^(feature|bugfix|hotfix|release|chore|docs|refactor|test|ci|perf)/[a-z0-9-]+$"
// Añadido "perf" para performance
```

### Requerir resolución de comentarios antes de merge

Edita `ruleset-proteccion-rama.json`:
```json
"required_review_thread_resolution": true  // Cambiar de false a true
```

---

## ⚠️ Bypass de Rulesets

Los rulesets actuales permiten que **administradores del repositorio** (role ID: 5) puedan hacer bypass de todas las reglas.

Para cambiar esto, edita el campo `bypass_actors` en cada JSON:

```json
"bypass_actors": []  // Sin bypass para nadie
```

O especifica roles/usuarios específicos:
```json
"bypass_actors": [
  {
    "actor_type": "OrganizationAdmin",
    "actor_id": 1,
    "bypass_mode": "always"
  }
]
```

---

## 📚 Recursos

- [GitHub Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [Semantic Versioning Specification](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub CLI (gh) Installation](https://cli.github.com/)

---

## 🆘 Solución de Problemas

### Error: "Branch name doesn't match pattern"

Tu nombre de rama no cumple la convención. Usa el formato: `tipo/descripcion`

```bash
# ❌ Mal
git checkout -b my-branch

# ✅ Bien
git checkout -b feature/my-branch
```

### Error: "Tag name doesn't match pattern"

Tu tag no usa Semantic Versioning.

```bash
# ❌ Mal
git tag release-1

# ✅ Bien
git tag v1.0.0
```

### Error: "Required status check 'tests' must pass"

El job `tests` del workflow de CI/CD falló. Revisa los logs en GitHub Actions y corrige los errores antes de hacer merge.

### ¿Cómo renombrar una rama incorrecta?

```bash
# Si NO has hecho push
git branch -m old-name feature/correct-name

# Si YA hiciste push
git branch -m old-name feature/correct-name
git push origin --delete old-name
git push origin feature/correct-name
```

---

## ✅ Estado de Rulesets por Repositorio

| Repositorio | Nomenclatura Ramas | Protección Main | Protección Tags |
|-------------|-------------------|-----------------|-----------------|
| backend | ✅ Activo | ✅ Activo | ✅ Activo |
| frontend | ✅ Activo | ✅ Activo | ✅ Activo |
| infrastructure | ✅ Activo | ✅ Activo | ✅ Activo |
| kong | ✅ Activo | ✅ Activo | ✅ Activo |
| kubernetes | ✅ Activo | ✅ Activo | ✅ Activo |
