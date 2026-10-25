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

**Result (2026-10-24):** `Plan: 2 to add`; public subnet `subnet-084e577541c2491a1`,
private subnet `subnet-09d4701625a662acb`.

### Questions answered

- **`vpc_id = aws_vpc.this.id`**: a reference, `<type>.<name>.<attribute>`. It means
  "the ID of the VPC resource called `this` in this code". Terraform uses references to work
  out the order (VPC before subnets on apply, the reverse on destroy), and the subnet always
  gets the right ID, even after the VPC is recreated with a new one.
- **`map_public_ip_on_launch = false`**: servers launched in this subnet do not get a public
  IP automatically (the workstation's subnet has it on, which is why the workstation got one).
- **Why a public subnet?** Only for the NAT gateway (step 1.4). The NAT gateway must be able
  to reach the internet gateway, and a subnet with a route to the internet gateway is a
  public subnet. No servers go there.
- **Why an Elastic IP?** Slurm does not need one; it only uses private IPs. A public NAT
  gateway needs a fixed public address to send the servers' outgoing traffic from, and AWS
  requires an Elastic IP for it.

---

## Step 1.3: Internet gateway + public route table

A **route table** is a list of rules: "traffic for this destination goes there".
Every subnet uses exactly one route table. A subnet is **public** when its route table sends
`0.0.0.0/0` (everything) to an **internet gateway**.

**Code:** four new resources in `vpc.tf`:

| Resource | Console name | What |
|---|---|---|
| `aws_internet_gateway.this` | `slurm-dev-igw` | the VPC's connection to the internet, attached to slurm-dev-vpc |
| `aws_route_table.public` | `slurm-dev-public-rt` | new route table for the public subnet |
| `aws_route.public_internet` | route in that table | `0.0.0.0/0 → slurm-dev-igw` |
| `aws_route_table_association.public` | Subnet associations tab | links the public subnet to `slurm-dev-public-rt` |

Routes in `slurm-dev-public-rt` after apply:

| Destination | Target | Meaning |
|---|---|---|
| 172.21.0.0/16 | local | traffic inside the VPC stays inside (added by AWS, cannot be removed) |
| 0.0.0.0/0 | igw-... | everything else goes to the internet |

The most specific route wins: 172.21.10.5 matches `/16` (local) better than `/0`.

The private subnet still uses the VPC's **main** route table (only `local`), so it has no
internet yet. That comes with the NAT gateway in step 1.4.

An internet gateway alone does not make servers reachable: a server also needs a public IP
and a security group that allows the traffic. Our Slurm servers will have neither.

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make plan     # expect: Plan: 4 to add, 0 to change, 0 to destroy.
make apply
make output   # internet_gateway_id and public_route_table_id added
```

**Check in the console:**

| Console page | What you should see |
|---|---|
| VPC > Internet gateways | `slurm-dev-igw`, State **Attached**, VPC slurm-dev-vpc |
| VPC > Route tables > `slurm-dev-public-rt` > Routes | `172.21.0.0/16 local` and `0.0.0.0/0 igw-...` |
| same > Subnet associations | `slurm-dev-public-ap-south-2a` |
| VPC > Subnets > private subnet > Route table | still the main route table, only `local` |
| Your VPCs > slurm-dev-vpc > Resource map | Route tables (2), Network connections: the IGW |

**Cost:** internet gateways are free.

**Result (2026-10-24):** `Plan: 4 to add`; internet gateway `igw-02329a8b026cd6d65`,
public route table `rtb-025e7406cb23f8f59` (association `rtbassoc-0f442360012fe6f17`).

---

## Step 1.4: NAT gateway + private route table

The Slurm servers will have only private IPs, but they must download packages (dnf, pip,
the Slurm source). A **NAT gateway** (Network Address Translation) forwards their outgoing
traffic to the internet using its own public IP and passes the replies back, like a home
Wi-Fi router. Nobody on the internet can start a connection to the servers.

```
slurm-node-1 172.21.10.x (private subnet)
   | private route table: 0.0.0.0/0 -> NAT gateway
   v
NAT gateway + Elastic IP (public subnet)
   | public route table: 0.0.0.0/0 -> internet gateway
   v
internet gateway -> internet (Red Hat repos, pypi, schedmd.com)
```

An **Elastic IP** is a public IPv4 address reserved in the account; it stays the same until it
is released (the workstation's 40.192.85.194 is one). A public NAT gateway requires one.
Slurm itself does not use it.

**Code:** five new resources in `vpc.tf`:

| Resource | Console name | What |
|---|---|---|
| `aws_eip.nat` | `slurm-dev-nat-eip` | Elastic IP for the NAT gateway |
| `aws_nat_gateway.this` | `slurm-dev-nat` | NAT gateway in the **public** subnet |
| `aws_route_table.private` | `slurm-dev-private-rt` | new route table for the private subnet |
| `aws_route.private_nat` | route in that table | `0.0.0.0/0 → slurm-dev-nat` |
| `aws_route_table_association.private` | Subnet associations tab | links the private subnet to `slurm-dev-private-rt` |

`depends_on = [aws_internet_gateway.this]` on the Elastic IP and NAT gateway: Terraform orders
resources by references, but nothing in their code refers to the internet gateway. Without
it, Terraform could create (or on destroy, keep) them in the wrong order.

Routes after apply:

| Route table | Subnet | 172.21.0.0/16 | 0.0.0.0/0 |
|---|---|---|---|
| slurm-dev-public-rt | public | local | internet gateway |
| slurm-dev-private-rt | private | local | NAT gateway |
| main (unnamed) | none | local | none |

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make plan     # expect: Plan: 5 to add, 0 to change, 0 to destroy.
make apply    # the NAT gateway takes 1-2 minutes ("Still creating...")
make output   # nat_gateway_id, nat_public_ip, private_route_table_id added
```

**Check in the console:**

| Console page | What you should see |
|---|---|
| VPC > Elastic IPs | `slurm-dev-nat-eip`, associated with the NAT gateway's network interface |
| VPC > NAT gateways | `slurm-dev-nat`, State **Available**, Connectivity type Public, subnet `slurm-dev-public-ap-south-2a`, same Elastic IP |
| VPC > Route tables > `slurm-dev-private-rt` > Routes | `172.21.0.0/16 local` and `0.0.0.0/0 nat-...` |
| same > Subnet associations | `slurm-dev-private-ap-south-2a` |
| Your VPCs > slurm-dev-vpc > Resource map | Route tables (3), Network connections: IGW and NAT |

The internet access itself is tested in stage 2, when there is a server in the private subnet
(`curl -s https://checkip.amazonaws.com` on it must print the NAT Elastic IP).

**Cost:** this step starts charges: NAT gateway ~$0.06/hour (~$45/month) plus ~$0.06/GB of
data, Elastic IP ~$0.005/hour. `make destroy` stops them. If you pause for several days
before stage 2, consider `make destroy` and `make apply` again later.

**2026-10-24:** the whole stack was removed overnight with `make destroy` to save the NAT
cost, and re-created on 2026-10-25 with `make apply`. All IDs change after a re-create;
`make output` shows the current ones.

---

## Step 1.5: VPC peering to workstation-vpc

Two VPCs are separate networks: by default the workstation (172.22.7.210) cannot reach
anything in 172.21.0.0/16. A **VPC peering connection** joins them so they talk by private
IP, without going through the internet.

```
workstation-vpc 172.22.0.0/16                        slurm-dev-vpc 172.21.0.0/16
  workstation 172.22.7.210                             private subnet 172.21.10.0/24
  route table (existing):                              slurm-dev-private-rt:
    172.21.0.0/16 -> pcx-...  (added) <== peering ==>    172.22.0.0/16 -> pcx-...
```

Peering needs:

1. CIDRs that **do not overlap** (172.21 vs 172.22: OK).
2. The connection **requested and accepted**. Same account and region, so `auto_accept = true`
   does both.
3. A **route on both sides**. Without the return route, packets go out and the replies are lost.
4. Security groups that allow the traffic (stage 2: the Slurm servers will allow SSH from
   the workstation).

Peering is not transitive: the workstation can reach slurm-dev-vpc, but cannot use its NAT
gateway, and slurm-dev-vpc cannot use the workstation's internet gateway.

**New idea: `data` sources.** A `resource` is something Terraform creates and owns. A `data`
source only **reads** something that already exists. Terraform never changes or deletes it.
The workstation VPC was made by hand, so Terraform reads it:

| Block | What it reads |
|---|---|
| `data.aws_vpc.workstation` | workstation-vpc by ID → its CIDR 172.22.0.0/16 |
| `data.aws_route_table.workstation` | the route table used by `subnet-0c71b9f5fd4fb972f` |

**Code:** new file `peering.tf`, two new variables (`workstation_vpc_id`,
`workstation_subnet_id`):

| Resource | Console | What |
|---|---|---|
| `aws_vpc_peering_connection.workstation` | Peering connections > `slurm-dev-to-workstation` | requester slurm-dev-vpc, accepter workstation-vpc |
| `aws_route.private_to_workstation` | `slurm-dev-private-rt` > Routes | `172.22.0.0/16 → pcx-...` |
| `aws_route.workstation_to_slurm` | **workstation** route table > Routes | `172.21.0.0/16 → pcx-...` |

The only change in workstation-vpc is that one route. `make destroy` removes that route and
the peering, nothing else in workstation-vpc.

The public subnet gets no route to the workstation: only the NAT gateway lives there.

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make plan     # if the stack still exists: Plan: 3 to add, 0 to change, 0 to destroy.
              # after last night's destroy:  Plan: 15 to add (12 from steps 1.1-1.4 + 3)
make apply
make output   # peering_connection_id, workstation_route_table_id added
```

In the plan, check that the route `aws_route.workstation_to_slurm` uses the workstation's
route table ID, and that nothing is planned to **change** or **destroy**.

If the plan fails with `no matching Route Table found`, the workstation subnet has no
explicit route table association (it uses its VPC's main route table). Then tell me and
we look it up differently.

**Check in the console:**

| Console page | What you should see |
|---|---|
| VPC > Peering connections | `slurm-dev-to-workstation`, Status **Active**, requester CIDR 172.21.0.0/16, accepter CIDR 172.22.0.0/16 |
| VPC > Route tables > `slurm-dev-private-rt` > Routes | local, `0.0.0.0/0 → nat-...`, `172.22.0.0/16 → pcx-...` |
| VPC > Route tables > workstation's route table > Routes | its old routes (local, `0.0.0.0/0 → igw-...`) and **new** `172.21.0.0/16 → pcx-...` |

Quick test from the workstation (there are no servers yet, so this only shows the route):

```bash
ip route get 172.21.10.10    # goes via the VPC router 172.22.x.1 as usual; AWS does the rest
```

The real test comes in stage 2: `ssh` from the workstation to a Slurm server's private IP.

**Result (2026-10-25):** applied together with the re-create of steps 1.1-1.4; peering Active,
routes on both sides. Stage 1 complete.

**Cost:** a peering connection is free. Traffic over it inside one AZ is free; across AZs
it is ~$0.01/GB each way (workstation and Slurm are both in ap-south-2a).
