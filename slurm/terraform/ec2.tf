# ---------------------------------------------------------------------------
# Step 2.3: the Slurm servers (EC2 instances)
# Console: EC2 > Instances
# ---------------------------------------------------------------------------

# Latest Red Hat Enterprise Linux 9 image, published by Red Hat.
# "data" again: Terraform only looks it up, like choosing the AMI in the console.
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat's official AWS account

  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*-Hourly2-GP3"] # pay-as-you-go RHEL 9, x86_64
  }
}

# for_each = one instance per entry in var.instances (terraform.tfvars).
# each.key   = the name, e.g. "slurm-master"
# each.value = its settings, e.g. { instance_type = "t3.medium" }
resource "aws_instance" "this" {
  for_each = var.instances

  ami                         = data.aws_ami.rhel9.id
  instance_type               = each.value.instance_type
  subnet_id                   = aws_subnet.private.id # private subnet: internet only out, via NAT
  vpc_security_group_ids      = [aws_security_group.slurm.id]
  key_name                    = aws_key_pair.slurm.key_name
  associate_public_ip_address = false

  # Same as the workstation: instance metadata only with IMDSv2 tokens.
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = each.key
    Role = each.key == "slurm-master" ? "master" : "node" # condition ? if-true : if-false
  }

  lifecycle {
    # Red Hat publishes new AMIs often. Without this, the next plan after a new
    # release would want to replace (delete + recreate) the running servers.
    ignore_changes = [ami]
  }
}
