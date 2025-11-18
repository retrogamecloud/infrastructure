module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true   # Fargate requiere NAT Gateway para acceso a Internet desde subnets privadas
  single_nat_gateway   = true   # Single NAT para dev (prod debería usar 3)
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.amazonaws.com/role/elb"             = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
    "karpenter.sh/discovery"                        = var.cluster_name
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
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets  # Cluster en subnets privadas
  cluster_endpoint_public_access = true

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
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = var.node_instance_types

    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = [aws_security_group.node_group.id]
  }

  eks_managed_node_groups = {
    general = {
      name = "${var.cluster_name}-node-group"

      subnet_ids = module.vpc.private_subnets

      desired_size = var.node_desired_size
      min_size     = var.node_min_size
      max_size     = var.node_max_size

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        role        = "general"
        environment = var.environment
      }

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-node-group"
          "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          "k8s.io/cluster-autoscaler/enabled"             = "true"
        }
      )
    }
  }

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.eks_admin.arn
      username = "eks-admin"
      groups   = ["system:masters"]
    },
  ]

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

  ingress {
    description = "Allow NodePort range from anywhere"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# Null resource para eliminar el tag kubernetes.io/cluster del primary security group
# Solo el node security group debe tener este tag para evitar conflictos con ELB Controller
resource "null_resource" "remove_cluster_sg_tag" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<-EOT
      # Obtener el cluster primary security group ID
      CLUSTER_SG=$(aws eks describe-cluster --name ${var.cluster_name} --region ${var.aws_region} --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
      
      # Eliminar el tag kubernetes.io/cluster/X si existe
      aws ec2 delete-tags \
        --region ${var.aws_region} \
        --resources $CLUSTER_SG \
        --tags Key=kubernetes.io/cluster/${var.cluster_name} \
        2>/dev/null || true
      
      echo "✅ Tag kubernetes.io/cluster/${var.cluster_name} eliminado del cluster primary SG: $CLUSTER_SG"
    EOT
  }

  triggers = {
    cluster_id = module.eks.cluster_id
  }
}

# ============================================================================
# EBS CSI Driver IAM Role
# ============================================================================
# IAM Role para EBS CSI Driver con IRSA (IAM Roles for Service Accounts)
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ebs-csi-driver"
    }
  )
}

# Attach AWS managed policy para EBS CSI Driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
