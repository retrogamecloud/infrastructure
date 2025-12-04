# 🧪 Testing - Infrastructure as Code (Terraform)

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-blueviolet?logo=terraform)](https://www.terraform.io/)
[![Jest](https://img.shields.io/badge/Jest-29.7-blue?logo=jest)](https://jestjs.io/)
[![TerraTest](https://img.shields.io/badge/TerraTest-latest-orange)](https://terratest.gruntwork.io/)

Testing strategy para Terraform IaC. Cubre validación, unit tests, integration tests y compliance checks para AWS infrastructure.

---

## 📋 Tabla de Contenidos

- [Descripción](#descripción)
- [Estructura de Tests](#estructura-de-tests)
- [Setup & Instalación](#setup--instalación)
- [Tipos de Tests](#tipos-de-tests)
- [Ejecutar Tests](#ejecutar-tests)
- [Terraform Plan Testing](#terraform-plan-testing)
- [Integration Tests](#integration-tests)
- [Compliance & Security](#compliance--security)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

---

## 📖 Descripción

Suite de tests para validar infraestructura Terraform:

✅ **Terraform Validation** - Syntax y structure válidos  
✅ **Format Compliance** - Code style (terraform fmt)  
✅ **Security Scanning** - tfsec, checkov, sentinel  
✅ **Plan Testing** - Verificar outputs y recursos creados  
✅ **Unit Tests** - Jest para lógica de modules  
✅ **Integration Tests** - TerraTest para AWS real (staging)  
✅ **Cost Estimation** - Terraform cost validation  
✅ **Documentation** - Verificar inputs/outputs documentados  

---

## 📁 Estructura de Tests

```
infrastructure/
├── tests/
│   ├── README.md                  # Este archivo
│   ├── terraform/
│   │   ├── eks.test.js           # Tests para módulo EKS
│   │   ├── vpc.test.js           # Tests para módulo VPC
│   │   ├── rds.test.js           # Tests para módulo RDS
│   │   └── monitoring.test.js    # Tests para monitoreo
│   ├── e2e/
│   │   ├── eks-cluster.test.go   # Go tests con TerraTest
│   │   ├── vpc-networking.test.go
│   │   └── rds-database.test.go
│   ├── security/
│   │   ├── tfsec.sh              # Security scanning
│   │   ├── checkov.sh            # Compliance checks
│   │   └── policies.tf           # OPA/Sentinel policies
│   ├── fixtures/
│   │   ├── terraform.tfvars.example
│   │   ├── valid-eks.tf
│   │   └── invalid-vpc.tf
│   └── utils/
│       ├── plan-parser.js        # Parse terraform plan JSON
│       ├── cost-estimator.js     # Estimar costos
│       └── helpers.js
├── terraform/
│   ├── eks/
│   ├── vpc/
│   ├── rds/
│   └── ...
└── README.md
```

---

## ⚙️ Setup & Instalación

### Requisitos Previos

```bash
# Terraform 1.5+
terraform --version
# Terraform v1.5.0

# Node.js 20+
node --version
# v20.19.5

# Go 1.21+ (para TerraTest)
go version
# go version go1.21.0

# AWS CLI
aws --version
# aws-cli/2.13+

# Security tools
tfsec --version    # Terraform security scanner
checkov --version  # Cloud security scanner
```

### Instalación

```bash
# 1. Navegar al directorio
cd infrastructure

# 2. Instalar Node dependencies
npm install

# 3. Instalar Go dependencies (si hay tests TerraTest)
cd tests
go mod download
cd ..

# 4. Instalar security tools
# macOS
brew install tfsec checkov

# Ubuntu
sudo apt-get install -y tfsec
pip3 install checkov

# 5. Crear .env.test
cat > .env.test << EOF
AWS_REGION=eu-west-1
TERRAFORM_VERSION=1.5
CLUSTER_VERSION=1.34
ENABLE_COST_CALCULATION=true
EOF

# 6. Crear archivo tfvars de test
cp tests/fixtures/terraform.tfvars.example terraform.tfvars.test
```

---

## 🧪 Tipos de Tests

### 1. Terraform Validation

```bash
# Verificar sintaxis
terraform validate

# Formatear código
terraform fmt -recursive

# Verificar formato sin cambiar
terraform fmt -check -recursive
```

### 2. Plan Parsing Tests

```javascript
// tests/terraform/eks.test.js
const fs = require('fs');
const parsePlan = require('../utils/plan-parser');

describe('EKS Module - Plan Validation', () => {
  let tfPlan;

  beforeAll(async () => {
    // Generar plan
    const { exec } = require('child_process');
    const { promisify } = require('util');
    const execPromise = promisify(exec);

    await execPromise('terraform plan -out=tfplan.json -json > plan.json', {
      cwd: './terraform/eks'
    });

    // Parsear
    tfPlan = parsePlan('./plan.json');
  });

  test('debe crear un EKS cluster', () => {
    const clusterCreation = tfPlan.resources.changes.find(
      change => change.type === 'aws_eks_cluster' && 
                change.change.actions.includes('create')
    );

    expect(clusterCreation).toBeDefined();
  });

  test('EKS cluster debe tener versión 1.34', () => {
    const cluster = tfPlan.resources.changes.find(
      change => change.type === 'aws_eks_cluster'
    );

    expect(cluster.change.after.kubernetes_version).toBe('1.34');
  });

  test('debe crear 2 subnets para EKS', () => {
    const subnets = tfPlan.resources.changes.filter(
      change => change.type === 'aws_subnet' && 
                change.change.after.tags.Type === 'EKS'
    );

    expect(subnets).toHaveLength(2);
  });

  test('Security Group debe permitir puerto 443', () => {
    const sg = tfPlan.resources.changes.find(
      change => change.type === 'aws_security_group' &&
                change.change.after.name.includes('eks')
    );

    const hasPort443 = sg.change.after.ingress.some(
      rule => rule.from_port === 443 && rule.cidr_blocks.includes('0.0.0.0/0')
    );

    expect(hasPort443).toBe(true);
  });
});
```

### 3. Security Scanning

```bash
#!/bin/bash
# tests/security/tfsec.sh

# Escanear seguridad
tfsec . \
  --format json \
  --out security-report.json

# Verificar severas
if grep -q '"severity":"CRITICAL"' security-report.json; then
  echo "❌ Critical security issues found!"
  exit 1
fi

# Verificar altas
HIGHS=$(grep -c '"severity":"HIGH"' security-report.json || echo 0)
if [ "$HIGHS" -gt 5 ]; then
  echo "⚠️  Too many HIGH severity issues ($HIGHS)"
  exit 1
fi

echo "✅ Security scan passed"
```

### 4. Compliance Checks

```javascript
// tests/terraform/compliance.test.js
const fs = require('fs');

describe('Compliance - Resource Tagging', () => {
  const tfvars = JSON.parse(fs.readFileSync('terraform.tfvars.json'));

  test('Todos los recursos deben tener tag "Environment"', async () => {
    const { execSync } = require('child_process');
    const plan = JSON.parse(
      execSync('terraform plan -json').toString()
    );

    plan.resource_changes.forEach(resource => {
      if (['aws_eks_cluster', 'aws_rds_instance'].includes(resource.type)) {
        expect(resource.change.after.tags).toHaveProperty('Environment');
      }
    });
  });

  test('Todos los RDS deben tener backups habilitados', async () => {
    const rds = tfPlan.resources.changes.find(
      change => change.type === 'aws_rds_instance'
    );

    expect(rds.change.after.backup_retention_period).toBeGreaterThan(0);
    expect(rds.change.after.backup_window).toBeDefined();
  });

  test('EKS debe tener control plane logging habilitado', () => {
    const cluster = tfPlan.resources.changes.find(
      change => change.type === 'aws_eks_cluster'
    );

    expect(cluster.change.after.enabled_cluster_log_types).toContain('api');
    expect(cluster.change.after.enabled_cluster_log_types).toContain('audit');
  });
});
```

### 5. Cost Estimation

```javascript
// tests/utils/cost-estimator.js
function estimateAWSCosts(tfPlan) {
  const costs = {
    eks_cluster: 73.00,           // $73/mes
    ec2_t3_medium: 0.0416 * 730,  // ~$30/mes
    ec2_t3_large: 0.0832 * 730,   // ~$60/mes
    rds_t3_small: 0.0385 * 730,   // ~$28/mes
    rds_t3_large: 0.1270 * 730,   // ~$92/mes
    alb: 16.00,                   // $16/mes
    nat_gateway: 32.00,           // $32/mes
  };

  let total = 0;
  let breakdown = {};

  // Contar recursos
  const resources = tfPlan.resource_changes;

  // EKS
  if (resources.some(r => r.type === 'aws_eks_cluster')) {
    breakdown.eks = costs.eks_cluster;
    total += costs.eks_cluster;
  }

  // EC2 Instances (nodos)
  const ec2Count = resources.filter(r => r.type === 'aws_instance').length;
  breakdown.ec2 = costs.ec2_t3_medium * ec2Count;
  total += breakdown.ec2;

  // RDS
  if (resources.some(r => r.type === 'aws_rds_instance')) {
    breakdown.rds = costs.rds_t3_small;
    total += breakdown.rds;
  }

  // ALB
  if (resources.some(r => r.type === 'aws_lb')) {
    breakdown.alb = costs.alb;
    total += costs.alb;
  }

  return {
    total: total,
    monthly: total,
    annual: total * 12,
    breakdown: breakdown
  };
}

module.exports = estimateAWSCosts;
```

### 6. Documentation Tests

```javascript
// tests/terraform/documentation.test.js
const fs = require('fs');
const path = require('path');

describe('Terraform Documentation', () => {
  const modules = ['eks', 'vpc', 'rds', 'alb'];

  modules.forEach(module => {
    describe(`${module} module`, () => {
      test(`debe tener variables.tf`, () => {
        const varsFile = path.join('./terraform', module, 'variables.tf');
        expect(fs.existsSync(varsFile)).toBe(true);
      });

      test(`debe tener outputs.tf`, () => {
        const outputsFile = path.join('./terraform', module, 'outputs.tf');
        expect(fs.existsSync(outputsFile)).toBe(true);
      });

      test(`debe tener README.md`, () => {
        const readmeFile = path.join('./terraform', module, 'README.md');
        expect(fs.existsSync(readmeFile)).toBe(true);
      });

      test(`variables deben tener descripción`, () => {
        const content = fs.readFileSync(
          path.join('./terraform', module, 'variables.tf'),
          'utf8'
        );

        // Cada variable debe tener descripción
        const varBlocks = content.match(/variable\s+"[^"]+"\s*{[^}]+}/g) || [];
        varBlocks.forEach(block => {
          expect(block).toMatch(/description\s*=/);
        });
      });

      test(`outputs deben tener descripción`, () => {
        const content = fs.readFileSync(
          path.join('./terraform', module, 'outputs.tf'),
          'utf8'
        );

        const outputBlocks = content.match(/output\s+"[^"]+"\s*{[^}]+}/g) || [];
        outputBlocks.forEach(block => {
          expect(block).toMatch(/description\s*=/);
        });
      });
    });
  });
});
```

---

## 🚀 Ejecutar Tests

### Validación Básica

```bash
# Validar sintaxis Terraform
npm run test:validate

# Formatear código
npm run test:format

# Verificar formato
npm run test:format:check
```

### Tests Unitarios

```bash
# Todos los unit tests
npm test

# Solo tests específicos
npm test eks
npm test vpc
npm test rds

# Con coverage
npm run test:coverage

# Modo watch
npm run test:watch
```

### Security Scanning

```bash
# Escanear con tfsec
npm run test:security

# Escanear con checkov
npm run test:checkov

# Ambos
npm run test:security:all
```

### Integration Tests (TerraTest)

```bash
# Solo si tienes acceso a AWS
npm run test:integration

# Con output detallado
npm run test:integration:verbose

# Específico módulo
npm run test:integration -- eks
```

### Plan Testing

```bash
# Generar y testear plan
npm run test:plan

# Con estimación de costos
npm run test:plan:costs
```

---

## 📊 CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/terraform-tests.yml
name: Terraform Tests

on: [push, pull_request]

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    env:
      AWS_REGION: eu-west-1
      TF_VERSION: 1.5

    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.5
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '20'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Terraform Format Check
      run: terraform fmt -check -recursive terraform/
    
    - name: Terraform Validate
      run: terraform validate
      working-directory: terraform
    
    - name: Run Jest Tests
      run: npm test
    
    - name: Security Scan (tfsec)
      run: npm run test:security
      continue-on-error: true
    
    - name: Compliance Check (checkov)
      run: npm run test:checkov
      continue-on-error: true
    
    - name: Generate Plan
      run: |
        cd terraform
        terraform init -backend=false
        terraform plan -json > /tmp/plan.json
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    
    - name: Upload Plan
      uses: actions/upload-artifact@v3
      with:
        name: terraform-plan
        path: /tmp/plan.json
```

---

## 🐛 Troubleshooting

### Error: "terraform: not found"

```bash
# Instalar Terraform
brew install terraform  # macOS
# o
terraform --version
```

### Error: "Cannot connect to AWS"

```bash
# Verificar credenciales
aws sts get-caller-identity

# O usar variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION=eu-west-1
```

### Terraform Plan Tests Fallan

```bash
# Generar plan manualmente
cd terraform/eks
terraform init -backend=false
terraform plan -json > plan.json

# Revisar contenido
cat plan.json | jq '.resource_changes[0]'
```

### Cost Estimation Incorrecta

```bash
# Verificar precios en AWS
# https://aws.amazon.com/ec2/pricing/on-demand/
# https://aws.amazon.com/rds/pricing/

# Actualizar cost-estimator.js con precios actuales
npm run test:plan:costs -- --verbose
```

---

## 📚 Recursos

- [Terraform Testing](https://www.terraform.io/docs/commands/validate.html)
- [TerraTest](https://terratest.gruntwork.io/)
- [tfsec](https://aquasecurity.github.io/tfsec/)
- [Checkov](https://www.checkov.io/)
- [AWS Pricing](https://aws.amazon.com/pricing/)

---

**Última actualización:** 1 de diciembre de 2025  
**Versión:** 1.0  
**Mantenedor:** RetroGameCloud DevOps Team
