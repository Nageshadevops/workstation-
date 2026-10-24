# Variables are declared here; their values are in terraform.tfvars.

locals {
  # Used at the start of every resource name, e.g. slurm-dev-vpc.
  name_prefix = "${var.project}-${var.environment}"
}

variable "project" {
  description = "Project name, used as a prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the Slurm VPC. Must not overlap workstation-vpc (172.22.0.0/16)."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for both subnets."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (NAT gateway only)."
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (Slurm servers)."
  type        = string
}
