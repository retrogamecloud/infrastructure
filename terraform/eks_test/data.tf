# =============================================================================
# REMOTE STATE - BOOTSTRAP
# =============================================================================
# Lee los outputs del proyecto bootstrap para obtener bucket y tabla DynamoDB

data "terraform_remote_state" "bootstrap" {
  backend = "local"

  config = {
    path = "../bootstrap/terraform.tfstate"
  }
}

# Data sources para EKS cluster authentication
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}
