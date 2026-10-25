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
workstation_vpc_id     = "vpc-0e9edd6e4c012d786"    # workstation-vpc, 172.22.0.0/16
workstation_subnet_id  = "subnet-0c71b9f5fd4fb972f" # workstation-subnet-public1-ap-south-2a
workstation_private_ip = "172.22.7.210"

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
ssh_public_key_path = "~/.ssh/slurm-dev-key.pub" # created by `make plan` if missing (SSH_KEY in Makefile)

# One entry = one server. To add a node, add a line; to remove one, delete its line.
instances = {
  "slurm-master" = { instance_type = "t3.medium" } # 2 vCPU / 4 GB: controller + database
  "slurm-node-1" = { instance_type = "t3.micro" }  # 2 vCPU / 1 GB: compute node
  "slurm-node-2" = { instance_type = "t3.micro" }
  "slurm-node-3" = { instance_type = "t3.micro" }
}
