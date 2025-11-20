module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true # Fargate requiere NAT Gateway para acceso a Internet desde subnets privadas
  single_nat_gateway   = true # Single NAT para dev (prod debería usar 3)
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.amazonaws.com/role/elb"         = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"                    = var.cluster_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-vpc"
    }
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets # Cluster en subnets privadas
  cluster_endpoint_public_access = true

  # Usar el security group del cluster pero sin tags conflictivos
  create_cluster_security_group = true
  cluster_security_group_tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
  
  # Evitar security groups adicionales en los nodos
  node_security_group_tags = {
    Name = "${var.cluster_name}-node-sg-additional"
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = var.node_instance_types

    attach_cluster_primary_security_group = false
    vpc_security_group_ids                = [aws_security_group.node_group.id]
  }

  eks_managed_node_groups = {
    general = {
      name = "general-nodes" # Nombre más corto

      iam_role_name            = "retrogamecloud-eks-node-role"
      iam_role_use_name_prefix = false # No añadir prefijos automáticos

      subnet_ids = module.vpc.private_subnets

      desired_size = var.node_desired_size
      min_size     = var.node_min_size
      max_size     = var.node_max_size

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      # Estrategia de actualización: fuerza reciclado de nodos cuando cambia el launch template
      update_config = {
        max_unavailable_percentage = 50 # Permite actualizar hasta 50% de nodos simultáneamente
      }

      # Forzar recreación al cambiar launch template
      force_update_version = true

      labels = {
        role        = "general"
        environment = var.environment
      }

      tags = merge(
        var.tags,
        {
          Name                                            = "${var.cluster_name}-node-group"
          "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          "k8s.io/cluster-autoscaler/enabled"             = "true"
        }
      )
    }
  }

  # En v20, el creador del cluster tiene acceso automático
  # Habilitamos permisos de administrador para el usuario de Terraform
  enable_cluster_creator_admin_permissions = true

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}

# Security Group para Node Group
resource "aws_security_group" "node_group" {
  name_prefix = "${var.cluster_name}-node-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow all internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # NodePort no es necesario ya que usamos LoadBalancer (Kong)
  # Si necesitas NodePort en el futuro, descomenta:
  # ingress {
  #   description = "Allow NodePort range"
  #   from_port   = 30000
  #   to_port     = 32767
  #   protocol    = "tcp"
  #   cidr_blocks = [var.vpc_cidr]  # Solo desde la VPC, no desde internet
  # }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-sg"
    }
  )
}

# IAM Role para administración del cluster
resource "aws_iam_role" "eks_admin" {
  name = "${var.cluster_name}-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-admin-role"
    }
  )
}

data "aws_caller_identity" "current" {}

# Actualizar kubeconfig automáticamente
resource "null_resource" "update_kubeconfig" {
  depends_on = [module.eks]

  triggers = {
    cluster_endpoint = module.eks.cluster_endpoint
    always_run       = timestamp() # Forzar ejecución en cada apply
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
  }
}

# Forzar actualización de nodos cuando cambie la configuración del nodegroup
resource "null_resource" "force_node_update" {
  depends_on = [module.eks]

  triggers = {
    # Ejecutar cuando cambien configuraciones clave del nodegroup
    node_instance_types = join(",", var.node_instance_types)
    node_desired_size   = var.node_desired_size
    node_min_size       = var.node_min_size
    node_max_size       = var.node_max_size
    ami_type            = "AL2023_x86_64_STANDARD"
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-nodegroup-version \
        --cluster-name ${var.cluster_name} \
        --nodegroup-name general-nodes \
        --force \
        --region ${var.aws_region} \
        --profile ${var.aws_profile} || true
    EOT
  }
}
