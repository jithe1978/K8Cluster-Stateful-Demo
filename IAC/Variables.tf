variable "region" {
  type    = string
  default = "us-east-2"
}

variable "cluster_name" {
  type    = string
  default = "mern-app-cluster"
}

# Reuse your existing network
variable "existing_vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

# Optional: create ECR repos
variable "create_ecr" {
  type    = bool
  default = true
}

# IAM principal who should get kubectl access
variable "admin_principal_arn" {
  type = string
}