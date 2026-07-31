module "s3" {
  source      = "../"
  initials    = var.initials
  surname     = var.surname
  resource    = var.resource
  environment = var.environment
}

module "eks" {
  source = "./modules/eks"

  # Optional: override module defaults
  availability_zones = ["af-south-1a", "af-south-1b", "af-south-1c"]
  vpc_id             = "vpc-04afeafc288c397af"
  rt_id              = "rtb-023fc1846d75af176"
  prefix             = "sherwin"
  environment        = var.environment
  capacity_type      = var.capacity_type # ON_DEMAND or SPOT (validated)
}