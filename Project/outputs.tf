# Displays the resources created for the selected environment. Shown at the end
# of `terraform apply`, and previewed by `terraform plan` (new values appear as
# "(known after apply)").

output "created_resources" {
  description = "Summary of the resources created for this environment."
  value = {
    environment = var.environment

    s3_buckets = concat(
      module.s3.my-bucket-output, # environment bucket (e.g. sunkersss4-<env>)
      module.s3.bucket-name-out,  # numbered buckets (e.g. sunkersss4-<env>-0..2)
    )

    eks_cluster = {
      name     = module.eks.cluster_name
      arn      = module.eks.cluster_arn
      endpoint = module.eks.cluster_endpoint
      role_arn = module.eks.cluster_role_arn
    }

    node_group = {
      name     = module.eks.node_group_name
      role_arn = module.eks.node_role_arn
    }

    subnets = {
      ids   = module.eks.subnet_ids
      cidrs = module.eks.subnet_cidrs
    }
  }
}
