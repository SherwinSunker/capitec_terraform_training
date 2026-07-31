resource "aws_s3_bucket" "terraform_state" {
  bucket = "sunkersss4-dev"
 
  tags = {
    Name        = "terraform-state"
    Environment = var.environment
    CreatedBy   = "Sherwin Sunker"
    CreatedVia  = "Terraform"
  }
}

capacity_type = var.capacity_type