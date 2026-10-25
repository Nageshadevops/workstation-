# ---------------------------------------------------------------------------
# Step 2.2: security group for the Slurm servers
# Console: EC2 > Security Groups (or VPC > Security groups) > slurm-dev-sg
#
# A security group is a firewall around each server. Inbound: only what a rule
# allows gets in. Replies to allowed traffic always get back out (stateful).
# ---------------------------------------------------------------------------
resource "aws_security_group" "slurm" {
  name        = "${local.name_prefix}-sg"
  description = "Slurm master and nodes"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-sg"
  }
}

# Slurm servers talk to each other on any port: munge, slurmctld 6817,
# slurmd 6818, slurmdbd 6819, srun's random ports, SSH between nodes.
# "referenced_security_group_id = itself" = any server that has this security group.
resource "aws_vpc_security_group_ingress_rule" "slurm_self" {
  security_group_id            = aws_security_group.slurm.id
  description                  = "All traffic between Slurm servers"
  ip_protocol                  = "-1" # all protocols and ports
  referenced_security_group_id = aws_security_group.slurm.id
}

# SSH only from the workstation (over the VPC peering). Terraform and Ansible run there.
resource "aws_vpc_security_group_ingress_rule" "ssh_from_workstation" {
  security_group_id = aws_security_group.slurm.id
  description       = "SSH from the workstation"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${var.workstation_private_ip}/32" # /32 = exactly this one address
}

# Ping from the workstation, handy for testing the peering.
resource "aws_vpc_security_group_ingress_rule" "ping_from_workstation" {
  security_group_id = aws_security_group.slurm.id
  description       = "Ping from the workstation"
  ip_protocol       = "icmp"
  from_port         = -1 # all ICMP types
  to_port           = -1
  cidr_ipv4         = "${var.workstation_private_ip}/32"
}

# Outbound: everything (dnf/pip through the NAT gateway, replies to the workstation).
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.slurm.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Every VPC gets a "default" security group that allows all traffic between its
# members. Taking it over with no rules empties it, so a server launched by mistake
# without slurm-dev-sg gets no access at all.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-default-sg-unused"
  }
}
