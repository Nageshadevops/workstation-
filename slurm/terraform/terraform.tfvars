project     = "slurm"
environment = "dev"
aws_region  = "ap-south-2" # Asia Pacific (Hyderabad)

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
vpc_cidr = "172.21.0.0/16"

availability_zone   = "ap-south-2a"
public_subnet_cidr  = "172.21.0.0/24"  # 172.21.0.0 - 172.21.0.255
private_subnet_cidr = "172.21.10.0/24" # 172.21.10.0 - 172.21.10.255

# ---------------------------------------------------------------------------
# Workstation (created by hand, see doc/Workstation-Setup.docx)
# ---------------------------------------------------------------------------
workstation_vpc_id    = "vpc-0e9edd6e4c012d786"    # workstation-vpc, 172.22.0.0/16
workstation_subnet_id = "subnet-0c71b9f5fd4fb972f" # workstation-subnet-public1-ap-south-2a

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
ssh_public_key_path = "~/.ssh/slurm-dev-key.pub" # on the workstation, see doc/02-vms.md step 2.1
