# Step 1.1: the VPC itself.
# Console: VPC > Your VPCs > slurm-dev-vpc
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # the VPC's DNS server (172.21.0.2) answers queries
  enable_dns_hostnames = true # instances get names like ip-172-21-10-5.ap-south-2.compute.internal

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}
