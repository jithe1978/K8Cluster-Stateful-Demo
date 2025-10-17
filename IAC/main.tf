# EKS using existing VPC + PUBLIC subnets
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = var.existing_vpc_id
  subnet_ids = var.public_subnet_ids

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  # Give your IAM user cluster-admin (so kubectl works immediately)
  access_entries = {
    admin_das = {
      principal_arn = var.admin_principal_arn

      policy_associations = {
        admin = {
          policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    public_ng = {
      name           = "public-ng"
      subnet_ids     = var.public_subnet_ids
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 2
    }
  }
}

# ECR (optional)
resource "aws_ecr_repository" "backend" {
  count = var.create_ecr ? 1 : 0
  name  = "mern-backend"
  image_scanning_configuration { scan_on_push = true }
}
resource "aws_ecr_repository" "frontend" {
  count = var.create_ecr ? 1 : 0
  name  = "mern-frontend"
  image_scanning_configuration { scan_on_push = true }
}

# Kubernetes provider AFTER cluster exists (exec token, Windows-safe)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}