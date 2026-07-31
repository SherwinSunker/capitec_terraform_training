resource "aws_s3_bucket" "s3_bucket_dev" {
  count  = 3
  bucket = "${local.bucket-name}-${count.index}"

  tags = {
    Name        = "s4_bucket_dev"
    Environment = "Dev"
    Createdby   = "Sherwin Sunker"
    CreateVia   = "Terraform"
  }
}

resource "aws_s3_bucket" "my-bucket" {
  # Only create the bucket for the environment currently being applied,
  # so dev/int/prod don't all try to create the same set of buckets.
  for_each = toset([var.environment])
  bucket   = "${var.surname}${var.initials}${var.resource}-${each.value}"

  tags = {
    Name        = "s4_bucket_int"
    Environment = each.value
    Createdby   = "Sherwin Sunker"
    CreateVia   = "Terraform"
  }
  lifecycle {
    #prevent_destroy = true
    #ignore_changes = []
  }
}

output "my-bucket-output" {
    value = [for b in aws_s3_bucket.my-bucket : b.bucket]
}

locals {
  bucket-name = "${var.surname}${var.initials}${var.resource}-${var.environment}"
}

output "bucket-name-out" {
  value = aws_s3_bucket.s3_bucket_dev[*].bucket
}

output "my-bucket-out" {
  value = aws_s3_bucket.s3_bucket_dev[*].bucket
}

variable "envs" {
  type    = list(string)
  default = ["dev", "int", "qa"]
}

variable "surname" {
  type    = string
  default = "sunker"
}

variable "initials" {
  type    = string
  default = "ss"
}

variable "resource" {
  type    = string
  default = "s4"
}

variable "environment" {
  type    = string
  default = "dev"
}