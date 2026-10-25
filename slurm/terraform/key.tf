# ---------------------------------------------------------------------------
# Step 2.1: SSH key pair for the Slurm servers
# Console: EC2 > Network & Security > Key pairs > slurm-dev-key
#
# The key is made on the workstation by `make plan` (ssh-keygen, only if missing).
# Terraform only uploads the PUBLIC key, so the private key is never in the state or in git.
# AWS puts the public key into ec2-user's ~/.ssh/authorized_keys at first boot.
# ---------------------------------------------------------------------------
resource "aws_key_pair" "slurm" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path)) # pathexpand turns ~ into /home/siddug
}
