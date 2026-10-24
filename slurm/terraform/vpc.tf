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

# ---------------------------------------------------------------------------
# Step 1.2: subnets
# Console: VPC > Subnets
# A subnet is "public" or "private" only because of its route table
# (steps 1.3 and 1.4), not because of a setting on the subnet itself.
# ---------------------------------------------------------------------------

# Public subnet: will hold only the NAT gateway.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false # nothing here should get a public IP by accident

  tags = {
    Name = "${local.name_prefix}-public-${var.availability_zone}"
    Tier = "public"
  }
}

# Private subnet: the Slurm master and nodes, private IPs only.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${local.name_prefix}-private-${var.availability_zone}"
    Tier = "private"
  }
}
