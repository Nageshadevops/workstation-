# Docs

Slurm test cluster on AWS (ap-south-2), built step by step with Terraform and Ansible
from the admin workstation.

```
laptop  --SSH-->  workstation (workstation-vpc 172.22.0.0/16)
                       |
                       |  VPC peering, private IPs only
                       v
                  slurm-dev-vpc 172.21.0.0/16
                    private subnet: slurm-master, slurm-node-1..3
                    internet for dnf/pip via NAT gateway
```

## Documents

| File | What |
|---|---|
| [Workstation-Setup.docx](Workstation-Setup.docx) | How the workstation VM was set up (console, by hand) |
| [01-vpc.md](01-vpc.md) | Stage 1: the Slurm VPC (Terraform) |
| [02-vms.md](02-vms.md) | Stage 2: SSH key, security group, the 4 VMs (Terraform) |

## How we work

1. Code is written on the laptop in this repo and pushed to GitHub.
2. On the workstation, as `siddug`:
   ```bash
   cd ~/workstation-
   git pull
   cd slurm
   make plan      # read what will change
   make apply
   ```
3. Check the result in the AWS console, then go to the next step.

Terraform state (`slurm/terraform/terraform.tfstate`) is kept **only on the workstation**
and is not in git. If it is lost, Terraform no longer knows what it created.

## Status

| Stage | Step | What | Status | Date |
|---|---|---|---|---|
| 1 VPC | 1.1 | VPC `slurm-dev-vpc` 172.21.0.0/16 (vpc-05a381e41ccd6dbac) | Done | 2026-10-24 |
| 1 VPC | 1.2 | Public + private subnet | Done | 2026-10-24 |
| 1 VPC | 1.3 | Internet gateway + public route table | Done | 2026-10-24 |
| 1 VPC | 1.4 | NAT gateway + private route table | Done | 2026-10-25 |
| 1 VPC | 1.5 | VPC peering to workstation-vpc | Done | 2026-10-25 |
| 1 VPC | 1.6 | Destroy / apply test | Done (destroy 2026-10-24, apply 2026-10-25) | 2026-10-25 |
| 2 VMs | 2.1 | SSH key pair `slurm-dev-key` | Code ready | 2026-10-25 |
| 2 VMs | 2.2 | Security group | To do | |
| 2 VMs | 2.3 | slurm-master + SSH / NAT test | To do | |
| 2 VMs | 2.4 | slurm-node-1..3 | To do | |
| 3 Slurm | | Ansible: munge, Slurm, slurmdbd | To do | |
