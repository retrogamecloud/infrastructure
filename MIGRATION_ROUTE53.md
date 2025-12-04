# Migración de Route53 Hosted Zone al Bootstrap

## 🎯 Objetivo

Mover la Hosted Zone de Route53 del módulo `terraform/eks/` al `terraform/bootstrap/` para que **los nameservers permanezcan constantes** incluso si destruyes y recreas el cluster EKS.

## ⚠️ Proceso de Migración (IMPORTANTE)

### Paso 1: Remover la Hosted Zone del estado de EKS

```bash
cd terraform/eks
terraform state rm aws_route53_zone.main
```

Esto **NO elimina** la Hosted Zone de AWS, solo la quita del estado de Terraform.

### Paso 2: Aplicar cambios en Bootstrap

```bash
cd ../bootstrap
terraform init
terraform plan
terraform apply
```

Terraform detectará que la Hosted Zone ya existe y te pedirá que la importes:

```bash
terraform import aws_route53_zone.main Z10264772Z8A8KXWT1EXH
```

Reemplaza `Z10264772Z8A8KXWT1EXH` con tu Zone ID actual.

### Paso 3: Verificar outputs

```bash
terraform output route53_zone_id
terraform output route53_nameservers
```

Estos nameservers ahora son **permanentes**.

### Paso 4: Aplicar cambios en EKS

```bash
cd ../eks
terraform init
terraform plan
terraform apply
```

Terraform ahora usará el Zone ID desde el bootstrap.

## 📋 Beneficios

- ✅ **Nameservers fijos**: Nunca cambiarán aunque destruyas el cluster
- ✅ **No más esperas**: No necesitas actualizar nameservers en Namecheap cada vez
- ✅ **Separación lógica**: DNS es infraestructura base, no parte del cluster
- ✅ **Protección**: `lifecycle.prevent_destroy` en la Hosted Zone

## 🔄 Comportamiento Actual

### Antes (Hosted Zone en EKS):
```
terraform destroy (EKS) → Elimina Hosted Zone → Nameservers cambian → Espera 1+ hora
```

### Después (Hosted Zone en Bootstrap):
```
terraform destroy (EKS) → Hosted Zone intacta → Nameservers fijos → Sin espera
```

## 📝 Estructura Final

```
bootstrap/
  └── route53.tf          # ✅ Hosted Zone (permanente)
  
eks/
  └── route53.tf          # ✅ Solo certificado SSL y registros A
```

## ⚠️ Importante

Si ya tienes la Hosted Zone creada y **NO quieres hacer la migración ahora**, puedes aplicar los cambios y luego:

```bash
cd terraform/bootstrap
terraform import aws_route53_zone.main <TU_ZONE_ID>

cd ../eks  
terraform state rm aws_route53_zone.main
terraform apply
```

Esto migrará el control sin recrear recursos.
