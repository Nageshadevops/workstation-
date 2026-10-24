# Stage 1: Slurm VPC

A separate VPC for the Slurm cluster, connected to `workstation-vpc` by VPC peering.
Everything here is created by Terraform, so `make destroy` removes it cleanly.

## Target (end of stage 1)

| Item | Value |
|---|---|
| VPC | `slurm-dev-vpc`, 172.21.0.0/16 |
| Public subnet | 172.21.0.0/24, ap-south-2a (only the NAT gateway lives here) |
| Private subnet | 172.21.10.0/24, ap-south-2a (Slurm servers, no public IPs) |
| Internet gateway | public subnet → internet |
| NAT gateway | private subnet → internet (outgoing only, for dnf/pip) |
| VPC peering | slurm-dev-vpc ↔ workstation-vpc (172.22.0.0/16) |

## Files

| File | What it holds |
|---|---|
| `slurm/Makefile` | the `make` commands |
| `slurm/terraform/versions.tf` | Terraform and AWS provider versions |
| `slurm/terraform/provider.tf` | AWS region and tags added to every resource |
| `slurm/terraform/variables.tf` | variable declarations (name, type, description) |
| `slurm/terraform/terraform.tfvars` | variable values (region, CIDRs) |
| `slurm/terraform/vpc.tf` | the network resources (grows step by step) |
| `slurm/terraform/outputs.tf` | values printed after apply |

## Make commands

| Command | Terraform | What it does |
|---|---|---|
| `make init` | `terraform init` | downloads the AWS provider into `terraform/.terraform/`; run once |
| `make fmt` | `terraform fmt -recursive` | tidies the formatting of `.tf` files |
| `make validate` | `terraform validate` | checks syntax and references; no AWS calls |
| `make plan` | `terraform plan -out=tfplan` | compares code with AWS and saves the planned changes |
| `make apply` | `terraform apply tfplan` | makes exactly the changes from the saved plan |
| `make output` | `terraform output` | shows IDs and other outputs |
| `make destroy` | `terraform destroy` | deletes everything in the state (asks `yes` first) |

`+` in a plan means create, `~` change in place, `-` delete, `-/+` delete and recreate.

---

## Step 1.1: VPC

**Code:** `vpc.tf` has one resource, `aws_vpc.this`:

| Setting | Value | Why |
|---|---|---|
| `cidr_block` | 172.21.0.0/16 | 65,536 addresses; does not overlap workstation-vpc (172.22.0.0/16), required for peering |
| `enable_dns_support` | true | the AWS DNS server in the VPC (172.21.0.2) works |
| `enable_dns_hostnames` | true | instances get DNS names |
| `Name` tag | slurm-dev-vpc | name shown in the console |

Tags `Project=slurm`, `Environment=dev`, `ManagedBy=terraform` are added by `provider.tf`.

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make init
make fmt validate
make plan     # expect: Plan: 1 to add, 0 to change, 0 to destroy.
make apply
make output   # vpc_id = "vpc-...", vpc_cidr = "172.21.0.0/16"
```

`make init` also creates `terraform/.terraform.lock.hcl`. It records the exact provider
version and should be committed to git (commit it from the workstation, or copy it to the laptop).

**Check in the console** (region Asia Pacific (Hyderabad)):

| Console page | What you should see |
|---|---|
| VPC > Your VPCs | `slurm-dev-vpc`, IPv4 CIDR 172.21.0.0/16, DNS hostnames and DNS resolution Enabled, the 3 tags |
| VPC > Route tables | one **main** route table for the new VPC, with only the `local` route (172.21.0.0/16) |
| VPC > Network ACLs | one **default** ACL, allows all traffic |
| VPC > Security groups | one **default** security group for the new VPC |

AWS creates the main route table, default network ACL and default security group
automatically with every VPC. They have no Name tag and Terraform does not manage them yet;
they are deleted together with the VPC.

Or with the CLI:

```bash
aws ec2 describe-vpcs --filters Name=tag:Name,Values=slurm-dev-vpc \
  --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock,State:State}' --output table
```

**Cost:** a VPC by itself is free.

**Result (2026-10-24):** `slurm-dev-vpc` = `vpc-05a381e41ccd6dbac`, Available, 172.21.0.0/16,
DNS resolution and hostnames Enabled, main route table `rtb-0c340b420fcaa449b`,
main network ACL `acl-0f030172d5edc3570`.

---

## Step 1.2: Subnets

A subnet is a slice of the VPC's address range in **one** availability zone.
Every server is placed in exactly one subnet.

**Code:** two new resources in `vpc.tf`, and three new variables:

| Resource | CIDR | Addresses | AZ | Used for |
|---|---|---|---|---|
| `aws_subnet.public` → `slurm-dev-public-ap-south-2a` | 172.21.0.0/24 | 172.21.0.0 – .255 | ap-south-2a | NAT gateway only (step 1.4) |
| `aws_subnet.private` → `slurm-dev-private-ap-south-2a` | 172.21.10.0/24 | 172.21.10.0 – .255 | ap-south-2a | Slurm master + 3 nodes (stage 2) |

- A /24 has 256 addresses, but AWS keeps 5 in every subnet (network address, router `.1`,
  DNS `.2`, reserved `.3`, broadcast `.255`), so 251 are usable.
- `map_public_ip_on_launch = false` on the public subnet: servers launched there do not get a
  public IP automatically. The NAT gateway gets its own Elastic IP in step 1.4.
- Both subnets are in one AZ: simple and cheap (one NAT gateway, no cross-AZ traffic charges).
  Fine for a test cluster, but if ap-south-2a has an outage, the cluster is down.
- **Right now both subnets are the same**: they use the VPC's main route table, which only
  has the `local` route. "Public" and "private" are just names until steps 1.3 and 1.4
  give them their own route tables.

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make plan     # expect: Plan: 2 to add, 0 to change, 0 to destroy.
make apply
make output   # public_subnet_id and private_subnet_id added
```

No `make init` needed: no new provider. The VPC is not changed, because Terraform compares
the code with its state and only the 2 subnets are new.

**Check in the console:**

| Console page | What you should see |
|---|---|
| VPC > Subnets (filter by VPC `slurm-dev-vpc`) | 2 subnets, ap-south-2a, CIDRs 172.21.0.0/24 and 172.21.10.0/24, 251 available IPv4 addresses each |
| a subnet > Details | Auto-assign public IPv4 address: **No** |
| a subnet > Route table tab | the **main** route table `rtb-0c340b420fcaa449b`, only route `172.21.0.0/16 → local` |
| VPC > Your VPCs > slurm-dev-vpc > Resource map | Subnets (2) |

**Cost:** subnets are free.
