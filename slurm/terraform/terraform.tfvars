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
workstation_vpc_id     = "vpc-048b5c867ebd27427"
workstation_subnet_id  = "subnet-013a5b6e081ff7e64"
workstation_private_ip = "172.22.7.185"

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
ssh_public_key_path = "~/.ssh/slurm-dev-key.pub" # created by `make plan` if missing (SSH_KEY in Makefile)

# One entry = one server. To add a node, add a line; to remove one, delete its line.
instances = {
  "slurm-master" = { instance_type = "t3.micro" } # 2 vCPU / 4 GB: controller + database
  "slurm-node-1" = { instance_type = "t3.micro" }  # 2 vCPU / 1 GB: compute node
  "slurm-node-2" = { instance_type = "t3.micro" }
  "slurm-node-3" = { instance_type = "t3.micro" }
}
