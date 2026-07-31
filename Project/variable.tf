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

variable "capacity_type" {
  type        = string
  description = "Type of capacity to launch (ON_DEMAND or SPOT)"
  default     = "SPOT"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be either ON_DEMAND or SPOT."
  }
}