region          = "us-east-2"
cluster_name    = "mern-app-cluster"
existing_vpc_id = "vpc-05938ff46d838a576" # real VPC ID
public_subnet_ids = [
  "subnet-0619ef1c1e25db557", # real public subnet in us-east-2a
  "subnet-05a5aff2259674a8c", # real public subnet in us-east-2b
]

admin_principal_arn = "arn:aws:iam::577999460012:user/das"
create_ecr          = true