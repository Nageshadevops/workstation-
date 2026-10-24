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
