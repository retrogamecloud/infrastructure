# Infrastructure - RetroGameCloud

Componentes de infraestructura para el proyecto RetroGameCloud.

## 📦 Contenido

### CDN (Content Delivery Network)

Servicio CDN basado en Nginx para servir archivos estáticos del proyecto.

**Contenido:**
- `cdn/Dockerfile` - Imagen Docker del CDN
- `cdn/cdn.conf` - Configuración de Nginx
- `cdn/juegos/` - Archivos .jsdos de los juegos retro
- `cdn/img/` - Thumbnails de los juegos

**Puerto:** 8086

**Workflow CI/CD:** `.github/workflows/docker-publish.yml`
- Se dispara automáticamente cuando hay cambios en `cdn/**`
- Construye y publica a GHCR y Docker Hub

## 🚀 Uso

### Build local

```bash
cd cdn
docker build -t retrogamecloud/gamescdn:local .
```

### Run local

```bash
docker run -d \
  --name games-cdn \
  -p 8086:80 \
  retrogamecloud/gamescdn:local
```

### Acceder al CDN

- Juegos: `http://localhost:8086/juegos/<juego>.jsdos`
- Imágenes: `http://localhost:8086/img/<imagen>.jpg`

## 📝 Agregar nuevos juegos

1. Coloca el archivo `.jsdos` en `cdn/juegos/`
2. Coloca el thumbnail `.jpg` en `cdn/img/`
3. Commit y push - el workflow construirá automáticamente la nueva imagen

## 🔗 Imágenes publicadas

- **GHCR**: `ghcr.io/retrogamecloud/gamescdn:latest`
- **Docker Hub**: `retrogamehub/gamescdn:latest`

Con versionado automático: `v1.0.X` (basado en número de commits)
