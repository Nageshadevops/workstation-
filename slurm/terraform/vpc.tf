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

# ---------------------------------------------------------------------------
# Step 1.3: internet gateway + public route table
# Console: VPC > Internet gateways, VPC > Route tables
# ---------------------------------------------------------------------------

# The VPC's door to the internet. One per VPC; free.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Route table for the public subnet. AWS adds the "172.21.0.0/16 -> local" route itself.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

# "Everything that is not inside the VPC goes to the internet gateway."
# This route is what makes the subnet public.
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Use the public route table for the public subnet (instead of the VPC's main route table).
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Step 1.4: NAT gateway + private route table
# Console: VPC > Elastic IPs, VPC > NAT gateways, VPC > Route tables
# Costs money while it exists (~$0.06/h NAT + ~$0.005/h Elastic IP).
# ---------------------------------------------------------------------------

# Fixed public IP for the NAT gateway. All outgoing internet traffic from the
# Slurm servers leaves from this address.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }

  # Terraform cannot see this dependency from the code, so we state it:
  # a public IP in a VPC only works once the VPC has an internet gateway.
  depends_on = [aws_internet_gateway.this]
}

# The NAT gateway sits in the PUBLIC subnet, so it can reach the internet gateway.
# Creating it takes 1-2 minutes.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

# Route table for the private subnet.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

# "Everything that is not inside the VPC goes to the NAT gateway."
# Outgoing only: nobody on the internet can start a connection to the private subnet.
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

# Use the private route table for the private subnet (instead of the VPC's main route table).
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
