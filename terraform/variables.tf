variable "aws_region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "vm-docker-lab"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = "vpc-026b199b05a37ded5"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public ALB subnets"
  type        = list(string)

  default = [
    "172.31.48.0/24",
    "172.31.49.0/24"
  ]

  validation {
    condition = (
      length(var.public_subnet_cidrs) >= 2 &&
      length(var.public_subnet_cidrs) == length(var.availability_zones)
    )
    error_message = "Provide at least two public subnet CIDRs, with one CIDR for each Availability Zone."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)

  default = [
    "172.31.50.0/24",
    "172.31.51.0/24"
  ]

  validation {
    condition = (
      length(var.private_subnet_cidrs) >= 2 &&
      length(var.private_subnet_cidrs) == length(var.availability_zones)
    )
    error_message = "Provide at least two private subnet CIDRs, with one CIDR for each Availability Zone."
  }
}

variable "availability_zones" {
  description = "Availability zones for high availability"
  type        = list(string)

  default = [
    "ap-south-1a",
    "ap-south-1b"
  ]
}

variable "key_name" {
  description = "Existing EC2 key pair name for Jenkins SSH deployment"
  type        = string
  default     = "vm-docker-deployment-key"
}
