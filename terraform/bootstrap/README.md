# Terraform Bootstrap

Este proyecto crea la infraestructura base necesaria para:
- Almacenar el estado de Terraform de forma remota
- Gestionar usuarios IAM con permisos de administrador

## ¿Qué crea?

### Infraestructura de Backend
- **Bucket S3**: Almacena los archivos `.tfstate` de todos tus proyectos
- **Tabla DynamoDB**: Gestiona los locks para prevenir ejecuciones concurrentes
- **Políticas IAM**: Da permisos a los usuarios especificados

### Usuarios IAM
- **Usuarios IAM**: Crea los usuarios especificados en `admin_users`
- **Grupo Administrators**: Grupo con permisos de AdministratorAccess
- **Credenciales**: Genera contraseñas y access keys para cada usuario

## Uso

### 1. Inicializar y aplicar

```bash
cd infrastructure/terraform/bootstrap
terraform init
terraform plan
terraform apply
```

### 2. Copiar el nombre del bucket

Después de `terraform apply`, anota el output `terraform_state_bucket`:

```bash
terraform output terraform_state_bucket
```

### 3. Obtener credenciales de usuarios (opcional)

Para ver las contraseñas y access keys generadas:

```bash
# Ver contraseñas de consola
terraform output -json user_passwords | jq

# Ver access keys
terraform output -json user_access_keys | jq
```

### 4. Usar en otros proyectos

En tu proyecto principal (`eks_test`, etc), actualiza `provider.tf`:

```hcl
backend "s3" {
  bucket         = "retrogame-terraform-state-XXXXXXXXXX"  # Output del bootstrap
  key            = "eks/terraform.tfstate"
  region         = "eu-west-1"
  dynamodb_table = "terraform-lock"
  encrypt        = true
  profile        = "default"
}
```

## Importante

⚠️ **NUNCA hagas `terraform destroy` en este proyecto** a menos que quieras eliminar TODO el estado de Terraform de todos tus proyectos.

## Estado local

Este proyecto usa estado **local** (archivo `terraform.tfstate` en disco). 

**Debes hacer backup manual** de este archivo o subirlo a git (está en `.gitignore` por defecto).
