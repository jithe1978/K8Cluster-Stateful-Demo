output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "ecr_backend_repo_url" {
  description = "URL for the MERN Backend ECR repository."
  value       = try(aws_ecr_repository.backend[0].repository_url, null)
}

output "ecr_frontend_repo_url" {
  description = "URL for the MERN Frontend ECR repository."
  value       = try(aws_ecr_repository.frontend[0].repository_url, null)
}