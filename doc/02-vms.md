# Stage 2: The 4 VMs

The Slurm servers, in the private subnet of `slurm-dev-vpc` (see [01-vpc.md](01-vpc.md)),
reached from the workstation by private IP over the VPC peering.

## Target (end of stage 2)

| Server | Type | CPU / RAM | Slurm role (stage 3) |
|---|---|---|---|
| slurm-master | t3.medium | 2 vCPU / 4 GB | controller + accounting database |
| slurm-node-1 | t3.micro | 2 vCPU / 1 GB | compute node |
| slurm-node-2 | t3.micro | 2 vCPU / 1 GB | compute node |
| slurm-node-3 | t3.micro | 2 vCPU / 1 GB | compute node |

All: RHEL 9, private subnet 172.21.10.0/24, **no public IP**, login as `ec2-user` with
`~/.ssh/slurm-dev-key` from the workstation.

```
workstation 172.22.7.210 --ssh (peering)--> slurm-master 172.21.10.x
                                             slurm-node-1..3 172.21.10.x
                                                 | dnf/pip
                                                 v
                                             NAT gateway -> internet
```

---

## Step 2.1: SSH key pair

To log in to an EC2 instance you need a **key pair**. The public key goes on the server
(in `~/.ssh/authorized_keys`), and the private key stays with you. AWS stores only the public key
under a name (`slurm-dev-key`) and puts it on every new instance launched with that name.

The key is made **automatically on the workstation**: `make plan` first runs the Makefile
target `key`, which calls `ssh-keygen` **only if `~/.ssh/slurm-dev-key.pub` does not exist**.
Terraform uploads only the public half. The private key is never in Terraform state, git or AWS.

- No manual step: a new admin runs `git pull` and `make plan`, and gets their own key.
- `make destroy` deletes the key pair **in AWS** but not the files in `~/.ssh`, so the next
  `make apply` uploads the same key again, and the same key works for the new servers.
- Not chosen: generating the key inside Terraform (`tls_private_key`). That is also automatic,
  but the private key is then stored in plain text in the state file.

| File (on the workstation) | What | Share? |
|---|---|---|
| `~/.ssh/slurm-dev-key` | private key | **never**, permissions 600 |
| `~/.ssh/slurm-dev-key.pub` | public key | safe; Terraform reads it |

**Code:** new file `key.tf`, one resource, one new variable:

| Resource | Console | What |
|---|---|---|
| `aws_key_pair.slurm` | EC2 > Key pairs > `slurm-dev-key` | the public key read from `ssh_public_key_path` |

- `file(...)` reads a file from disk while Terraform runs, so the key must exist on the
  machine that runs `make plan` (the workstation).
- `pathexpand(...)` turns `~` into the home folder (`/home/siddug`).

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make plan     # first time: runs ssh-keygen, then: Plan: 1 to add, 0 to change, 0 to destroy.
make apply
make output   # key_pair_name = "slurm-dev-key"
ls -l ~/.ssh/slurm-dev-key*     # private: -rw-------, public: -rw-r--r--
```

The Makefile lines that do it:

```make
SSH_KEY := $(HOME)/.ssh/slurm-dev-key

key: $(SSH_KEY).pub

$(SSH_KEY).pub:                 # a file target: make runs it only if the file is missing
	mkdir -p -m 700 $(HOME)/.ssh
	ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -C "slurm-dev"

plan: key                       # plan needs the key first
```

`-N ""` = no passphrase, so Ansible can use the key without asking. `make key` creates the key
on its own, without planning. `SSH_KEY` in the Makefile and `ssh_public_key_path` in
`terraform.tfvars` must point to the same file.

**Check in the console:** EC2 > Network & Security > **Key pairs**: `slurm-dev-key`, type
**ED25519**. Compare its fingerprint with the workstation:

```bash
ssh-keygen -lf ~/.ssh/slurm-dev-key.pub   # SHA256:... (same as the console)
```

**Back up the private key.** If `~/.ssh/slurm-dev-key` is lost, you can no longer log in to the
Slurm servers. Recovery means a new key and new instances. A copy in a safe place on the laptop
is fine (never in git).

**Cost:** key pairs are free.

---

## Step 2.2: Security group

A **security group** is a firewall attached to each server's network interface.

- **Inbound:** nothing gets in unless a rule allows it.
- **Outbound:** controlled by egress rules (we allow all).
- **Stateful:** replies to allowed traffic always pass, in both directions, without extra rules.
- A rule's source can be an IP range (`cidr_ipv4`) or **another security group**: "every server
  that has security group X".

**Code:** new file `security.tf`, one new variable (`workstation_private_ip`):

| Resource | Console | Rule |
|---|---|---|
| `aws_security_group.slurm` | Security groups > `slurm-dev-sg` | the group itself, in slurm-dev-vpc |
| `aws_vpc_security_group_ingress_rule.slurm_self` | Inbound rules | **All traffic** from `slurm-dev-sg` (Slurm servers to each other) |
| `aws_vpc_security_group_ingress_rule.ssh_from_workstation` | Inbound rules | **TCP 22** from `172.22.7.210/32` |
| `aws_vpc_security_group_ingress_rule.ping_from_workstation` | Inbound rules | **ICMP** from `172.22.7.210/32` |
| `aws_vpc_security_group_egress_rule.all` | Outbound rules | All traffic to `0.0.0.0/0` |
| `aws_default_security_group.this` | Security groups > `slurm-dev-default-sg-unused` | VPC's default group, **all rules removed** |

Why these rules:

- **Self rule:** Slurm uses several ports (munge, 6817 slurmctld, 6818 slurmd, 6819 slurmdbd)
  plus random ports for `srun`, and the nodes SSH to each other. Allowing all traffic *inside the
  group* covers this, while nothing outside the group gets in.
- **SSH only from the workstation:** Terraform and Ansible run there; nobody else needs to log in.
  `/32` means exactly one address. The traffic arrives over the VPC peering with the
  workstation's private IP as the source.
- **No rule from the internet:** the servers have no public IP anyway (defence in depth).
- **Default security group:** AWS creates one in every VPC that lets its members talk freely.
  `aws_default_security_group` with no rules empties it, so a server launched without
  `slurm-dev-sg` by mistake is cut off instead of open.

Compared to the workstation's `workstation-sg` (SSH from `0.0.0.0/0`), this group is much stricter.

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make plan     # expect: Plan: 6 to add, 0 to change, 0 to destroy.
make apply
make output   # security_group_id added
```

**Check in the console** (EC2 > Network & Security > **Security Groups**, filter VPC `slurm-dev-vpc`):

| Group | Inbound rules | Outbound rules |
|---|---|---|
| `slurm-dev-sg` | All traffic from `sg-...` (itself); SSH 22 from 172.22.7.210/32; All ICMP-IPv4 from 172.22.7.210/32 | All traffic 0.0.0.0/0 |
| `slurm-dev-default-sg-unused` (group name `default`) | none | none |

Nothing can be tested yet: there are no servers. That is step 2.3.

**Cost:** security groups are free.

---

## Step 2.3: slurm-master

The first server. Everything built so far comes together here:

| Setting | Comes from | Step |
|---|---|---|
| `subnet_id` | `aws_subnet.private` | 1.2 |
| internet (outgoing) | private route table → NAT gateway | 1.4 |
| reachable from the workstation | peering + routes | 1.5 |
| `key_name` | `aws_key_pair.slurm` | 2.1 |
| `vpc_security_group_ids` | `aws_security_group.slurm` | 2.2 |

**Code:** new file `ec2.tf`, two new variables (`instances`, `root_volume_size`):

| Block | What |
|---|---|
| `data.aws_ami.rhel9` | looks up the newest RHEL 9 image from Red Hat (owner 309956199498), like picking it in the console |
| `aws_instance.this` | one EC2 instance **per entry in `instances`** (`for_each`) |

Instance settings:

| Setting | Value | Why |
|---|---|---|
| `instance_type` | t3.medium (from tfvars) | master runs slurmctld + slurmdbd + MariaDB, and compiles Slurm |
| `subnet_id` | private subnet | no direct internet access in |
| `associate_public_ip_address` | false | private IP only |
| `metadata_options.http_tokens` | required | IMDSv2 only, same as the workstation |
| `root_block_device` | 30 GiB gp3, encrypted | room for the Slurm build and MariaDB |
| `tags.Name` | slurm-master | name in the console |
| `tags.Role` | master / node | `condition ? a : b` = if/else |
| `lifecycle.ignore_changes = [ami]` | | a newer RHEL image must not replace running servers |

**New idea: `for_each`.** One resource block creates one instance per map entry:

```hcl
instances = {
  "slurm-master" = { instance_type = "t3.medium" }   # each.key = "slurm-master"
}                                                     # each.value.instance_type = "t3.medium"
```

In the state they are called `aws_instance.this["slurm-master"]`. Step 2.4 only adds three lines
to `instances` in `terraform.tfvars`; no new resource code.

The output `instances` uses a `for` expression to print a small map, name → id and private IP.

**New: `make ssh`.** It reads the private IP from `terraform output` and logs in with
`~/.ssh/slurm-dev-key` as `ec2-user`, so you never copy IPs by hand (they change on every
re-create). `make ssh HOST=slurm-node-1` for another server. It skips the known_hosts check,
because re-created servers get new host keys. Acceptable here: the servers are only
reachable from the workstation over the private network.

**Run on the workstation:**

```bash
cd ~/workstation- && git pull && cd slurm
make plan     # expect: Plan: 1 to add, 0 to change, 0 to destroy.
make apply    # ~30 s; the server needs another 1-2 minutes to boot
make output   # instances = { "slurm-master" = { id = "i-...", private_ip = "172.21.10.x" } }
```

**Test from the workstation:**

```bash
ping -c 3 <private_ip>            # peering + ICMP rule
make ssh                          # peering + SSH rule + key

# on slurm-master:
hostname -I                       # 172.21.10.x, no public IP
curl -s https://checkip.amazonaws.com   # must print nat_public_ip (make output): internet via NAT
sudo dnf -y check-update | tail -3      # Red Hat repos reachable
exit
```

| Test fails | Check |
|---|---|
| `ping` / `ssh` time out | peering Active? workstation route table has `172.21.0.0/16 → pcx-`? `slurm-dev-sg` allows 172.22.7.210? |
| `Permission denied (publickey)` | user must be `ec2-user`; key pair in the console is `slurm-dev-key` |
| `curl` / `dnf` hang on the server | private route table has `0.0.0.0/0 → nat-`? NAT gateway Available? |

**Check in the console** (EC2 > **Instances**):

| Tab | What you should see |
|---|---|
| Details | `slurm-master`, Running, t3.medium, AMI `RHEL-9.x...`, Private IPv4 172.21.10.x, **no** Public IPv4, Key pair `slurm-dev-key`, IMDSv2 Required |
| Networking | VPC slurm-dev-vpc, subnet `slurm-dev-private-ap-south-2a` |
| Security | security group `slurm-dev-sg` |
| Storage | 30 GiB gp3, Encrypted |
| Status checks | 2/2 checks passed (after ~2 minutes) |

The hostname will look like `ip-172-21-10-x`. Ansible sets it to `slurm-master` in stage 3.

**Cost:** t3.medium in ap-south-2 with the hourly RHEL licence is roughly $0.07–0.10/hour,
plus the 30 GiB disk (~$3/month). Check the current price in the EC2 console's launch page if
it matters. Stopping an instance stops the hourly charge (not the disk); `make destroy` stops both.
