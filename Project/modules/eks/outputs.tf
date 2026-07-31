# Outputs surfaced to the root module so the resources created by this module
# are visible in `terraform plan` / `terraform apply` output.

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.eks-cluster.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.eks-cluster.arn
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = aws_eks_cluster.eks-cluster.endpoint
}

output "node_group_name" {
  description = "Name of the managed node group."
  value       = aws_eks_node_group.eks-ng.node_group_name
}

output "subnet_ids" {
  description = "IDs of the subnets created for the cluster."
  value       = [aws_subnet.az1.id, aws_subnet.az2.id, aws_subnet.az3.id]
}

output "subnet_cidrs" {
  description = "CIDR blocks of the subnets created for the cluster."
  value       = [aws_subnet.az1.cidr_block, aws_subnet.az2.cidr_block, aws_subnet.az3.cidr_block]
}

output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role."
  value       = aws_iam_role.eks-cluster-role.arn
}

output "node_role_arn" {
  description = "ARN of the EKS node group IAM role."
  value       = aws_iam_role.node-iam-role.arn
}
