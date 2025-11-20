#!/bin/bash
# Script para crear los secrets necesarios para el backend

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Script de Inicialización de Secrets para Backend ===${NC}\n"

# Verificar que kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl no está instalado${NC}"
    exit 1
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: No se puede conectar al cluster de Kubernetes${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Conexión al cluster verificada${NC}\n"

# Solicitar información
echo -e "${YELLOW}Por favor, proporciona la siguiente información:${NC}\n"

read -p "RDS Endpoint (ej: retrogame-db.xxxxx.us-east-1.rds.amazonaws.com): " DB_HOST
read -p "Nombre de la base de datos [retrogame_db]: " DB_NAME
DB_NAME=${DB_NAME:-retrogame_db}

read -p "Usuario de la base de datos [postgres]: " DB_USER
DB_USER=${DB_USER:-postgres}

read -sp "Contraseña de la base de datos: " DB_PASSWORD
echo ""

read -sp "JWT Secret (déjalo vacío para generar uno aleatorio): " JWT_SECRET
echo ""

# Generar JWT secret si está vacío
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 32)
    echo -e "${GREEN}✓ JWT Secret generado automáticamente${NC}"
fi

# Confirmar datos
echo -e "\n${YELLOW}Datos a configurar:${NC}"
echo "  DB Host: $DB_HOST"
echo "  DB Name: $DB_NAME"
echo "  DB User: $DB_USER"
echo "  DB Password: ********"
echo "  JWT Secret: ********"
echo ""

read -p "¿Confirmas estos datos? (s/n): " CONFIRM
if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
    echo -e "${RED}Operación cancelada${NC}"
    exit 0
fi

# Crear secret
echo -e "\n${GREEN}Creando secret 'backend-secrets' en namespace 'default'...${NC}"

kubectl create secret generic backend-secrets \
  --from-literal=db-host="$DB_HOST" \
  --from-literal=db-name="$DB_NAME" \
  --from-literal=db-user="$DB_USER" \
  --from-literal=db-password="$DB_PASSWORD" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Secret creado exitosamente${NC}\n"
    
    # Verificar el secret
    echo -e "${GREEN}Verificando secret...${NC}"
    kubectl get secret backend-secrets -n default
    
    echo -e "\n${GREEN}=== Configuración completada ===${NC}"
    echo -e "${YELLOW}Nota: Guarda el JWT Secret en un lugar seguro si necesitas replicarlo${NC}"
else
    echo -e "${RED}✗ Error al crear el secret${NC}"
    exit 1
fi
