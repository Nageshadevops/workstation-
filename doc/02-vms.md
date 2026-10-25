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

We make the key **on the workstation** with `ssh-keygen`, and Terraform uploads only the public
half. The private key is never in Terraform state, git or AWS.

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
# 1. make the key (once). -N "" = no passphrase, so Ansible can use it without asking.
ssh-keygen -t ed25519 -f ~/.ssh/slurm-dev-key -N "" -C "slurm-dev"
ls -l ~/.ssh/slurm-dev-key*     # private: -rw-------, public: -rw-r--r--

# 2. upload the public key
cd ~/workstation- && git pull && cd slurm
make plan     # expect: Plan: 1 to add, 0 to change, 0 to destroy.
make apply
make output   # key_pair_name = "slurm-dev-key"
```

If `make plan` says `Invalid value for "path" parameter: no file exists`, step 1 was skipped
or the file name is different.

**Check in the console:** EC2 > Network & Security > **Key pairs**: `slurm-dev-key`, type
**ED25519**. Compare its fingerprint with the workstation:

```bash
ssh-keygen -lf ~/.ssh/slurm-dev-key.pub   # SHA256:... (same as the console)
```

**Back up the private key.** If `~/.ssh/slurm-dev-key` is lost, you can no longer log in to the
Slurm servers. Recovery means a new key and new instances. A copy in a safe place on the laptop
is fine (never in git).

**Cost:** key pairs are free.
