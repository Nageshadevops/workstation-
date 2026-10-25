# ---------------------------------------------------------------------------
# Step 1.5: VPC peering between slurm-dev-vpc and workstation-vpc
# Console: VPC > Peering connections, VPC > Route tables
#
# Peering joins two VPCs so they can talk by private IP. It needs a route on
# BOTH sides: each VPC must know that the other VPC's CIDR goes to the peering.
# ---------------------------------------------------------------------------

# "data" = read something that already exists. Terraform never changes or
# deletes it. Here: the workstation VPC, made by hand in the console.
data "aws_vpc" "workstation" {
  id = var.workstation_vpc_id
}

# The route table used by the workstation's subnet.
data "aws_route_table" "workstation" {
  subnet_id = var.workstation_subnet_id
}

# The peering connection. Both VPCs are in the same account and region, so
# Terraform can request and accept it in one go (auto_accept).
resource "aws_vpc_peering_connection" "workstation" {
  vpc_id      = aws_vpc.this.id               # requester: slurm-dev-vpc
  peer_vpc_id = data.aws_vpc.workstation.id   # accepter:  workstation-vpc
  auto_accept = true

  tags = {
    Name = "${local.name_prefix}-to-workstation"
  }
}

# Slurm side: from the private subnet, 172.22.0.0/16 goes to the peering.
resource "aws_route" "private_to_workstation" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = data.aws_vpc.workstation.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.workstation.id
}

# Workstation side: one route ADDED to the existing workstation route table,
# 172.21.0.0/16 goes to the peering. make destroy removes only this route.
resource "aws_route" "workstation_to_slurm" {
  route_table_id            = data.aws_route_table.workstation.id
  destination_cidr_block    = aws_vpc.this.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.workstation.id
}
