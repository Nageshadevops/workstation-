# Setup: laptop and workstation

What an admin needs before working on the Slurm cluster, and how to build the whole cluster
from zero. The workstation VM itself (VPC, instance, user, SSH hardening, base software) was
created by hand and is described in [Workstation-Setup.docx](Workstation-Setup.docx); this
document covers everything around it.

```
laptop (Windows 11 + WSL Ubuntu)
  │  git push ──────────────► GitHub: Nageshadevops/workstation-
  │  ssh -X siddug@40.192.85.194        │ git pull
  ▼                                     ▼
workstation (RHEL 9, user siddug): ~/workstation-/slurm  →  make ...  →  AWS + Slurm servers
```

| Where | What happens there |
|---|---|
| Laptop | edit code and docs, `git commit` / `git push`, SSH to the workstation |
| Workstation | `git pull`, all `make` commands (Terraform, Ansible); Terraform state and the Slurm SSH key live here |

---

## 1. Laptop (Windows 11)

### 1.1 WSL Ubuntu

In PowerShell **as administrator** (once, then reboot):

```powershell
wsl --install -d Ubuntu
```

Then open **Ubuntu** from the Start menu, create a Linux user, and install the tools:

```bash
sudo apt update && sudo apt install -y git openssh-client x11-apps
```

`x11-apps` gives `xclock`/`xeyes` to test the X server (1.5).

### 1.2 SSH key for the workstation

The key pair `workstation-key.pem` was downloaded when the workstation was created
(see Workstation-Setup.docx). SSH refuses keys with open permissions, and files under `/mnt/c`
cannot be restricted, so copy it into WSL:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<windows-user>/Desktop/pem-keys/workstation-key.pem ~/.ssh/
chmod 400 ~/.ssh/workstation-key.pem
```

A new admin gets their own login on the workstation from an existing admin (section 3) instead
of sharing this key.

### 1.3 Connect to the workstation

```bash
ssh siddug@40.192.85.194                                   # password (siddug only)
ssh -i ~/.ssh/workstation-key.pem siddug@40.192.85.194     # key
ssh -X siddug@40.192.85.194                                # with X11, for GUI jobs (1.5)
```

Optional shortcut in `~/.ssh/config` on the laptop, then just `ssh workstation`:

```
Host workstation
    HostName 40.192.85.194
    User siddug
    IdentityFile ~/.ssh/workstation-key.pem
    ForwardX11 yes
```

If `ssh` hangs: your public IP may not be allowed in `workstation-sg`
(`curl -s https://checkip.amazonaws.com`).

### 1.4 Git and GitHub

GitHub does not accept the account password for git over HTTPS; use a **personal access token**:
GitHub → Settings → Developer settings → **Fine-grained tokens** → repository
`Nageshadevops/workstation-` only, permission **Contents: Read and write**, with an expiry date.

```bash
git config --global user.name  "<your name>"
git config --global user.email "<your email>"
git config --global credential.helper store     # laptop: remember the token
cd /mnt/c/Users/<windows-user>
git clone https://github.com/Nageshadevops/workstation-.git
# Username: <github user>   Password: <the token>
chmod 600 ~/.git-credentials                    # after the first successful login
```

`store` keeps the token in plain text in `~/.git-credentials`. If the token leaks, delete it on
GitHub and make a new one.

### 1.5 X11 (GUI windows from the cluster)

Windows 11 WSL has a built-in X server (**WSLg**); nothing to install.

```bash
echo $DISPLAY      # :0
xclock             # a clock window opens: the laptop side works
```

---

## 2. Workstation (RHEL 9, user siddug)

Base software (git, make, jq, Python 3.11, Terraform, Ansible, AWS CLI) and `aws configure`
are in Workstation-Setup.docx, section 4. Check them:

```bash
git --version; terraform -version; ansible --version | head -1; aws --version; jq --version
aws sts get-caller-identity                   # AWS access works
ansible-galaxy collection list 2>/dev/null | grep -E 'ansible.posix|community.general'
```

The playbook uses the collections `ansible.posix` and `community.general`. Both come with the
full `ansible` pip package. If missing:
`ansible-galaxy collection install ansible.posix community.general`.

If `ansible: command not found`: `echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc && source ~/.bashrc`.

### 2.1 Git and GitHub

Same token idea as the laptop, but kept **in memory only** (the workstation is reachable from
the internet; better no token in a file there):

```bash
git config --global user.name  "<your name>"
git config --global user.email "<your email>"
git config --global credential.helper 'cache --timeout=28800'   # 8 hours
cd ~ && git clone https://github.com/Nageshadevops/workstation-.git
```

### 2.2 X11 forwarding (for GUI jobs)

The window travels laptop ← workstation ← slurm-master, so the workstation must forward X11 too:

```bash
sudo dnf install -y xorg-x11-xauth
sudo sshd -T | grep -i x11forwarding     # must say: x11forwarding yes
```

If it says `no`: `echo "X11Forwarding yes" | sudo tee /etc/ssh/sshd_config.d/10-x11.conf && sudo systemctl restart sshd`.

### 2.3 What lives only on the workstation (back it up)

| File | What | If lost |
|---|---|---|
| `~/workstation-/slurm/terraform/terraform.tfstate` | Terraform's record of what it created | Terraform no longer knows the resources; they must be deleted by hand in the console |
| `~/.ssh/slurm-dev-key` (+ `.pub`) | login key for the Slurm servers (created by `make plan`) | no login to existing servers; `make destroy` + `make apply` fixes it |
| `~/.aws/credentials` | AWS access keys of siddug | `aws configure` again with new keys |

None of these are in git (`.gitignore`). On the Slurm servers, the munge key and the database
password are generated by Ansible and are re-created with the cluster.

---

## 3. A new admin

1. An existing admin creates a Linux user on the workstation, as in Workstation-Setup.docx
   step 8 (`sudo useradd -m -G wheel <user>`, add their **public** SSH key to
   `/home/<user>/.ssh/authorized_keys`).
2. The new admin sets up their laptop (section 1) and their workstation account (section 2,
   including their own `aws configure`).
3. **Only one admin runs Terraform for this cluster**, from one folder: the state file is local
   to that folder. A second admin with their own clone would try to build a second cluster with
   the same names, and fail. For several admins, move the state to an S3 bucket with locking
   (not done yet).

---

## 4. Build the cluster from zero

On the workstation, after sections 1 and 2:

```bash
cd ~/workstation- && git pull && cd slurm
make init             # once per clone: download the AWS provider
make plan             # creates ~/.ssh/slurm-dev-key if missing; Plan: 26 to add
make apply            # VPC, NAT, peering, key pair, security group, 4 servers (~3 minutes)
make ping             # Ansible reaches all 4 servers (wait 1-2 minutes after apply)
make ansible-slurm    # whole Slurm setup (~20 minutes, mostly the compile)
make ssh              # log in to slurm-master
sinfo                 # debug*  up  infinite  3  idle  slurm-node-[1-3]
```

| Doc | Details |
|---|---|
| [01-vpc.md](01-vpc.md) | stage 1: network |
| [02-vms.md](02-vms.md) | stage 2: key, security group, servers |
| [03-slurm.md](03-slurm.md) | stage 3: Slurm with Ansible |

**Stop paying when done:** `make destroy` removes everything Terraform created (type `yes`).
The workstation and `workstation-vpc` are not touched, except for the one peering route.
Afterwards, `ansible/files/slurm-install-*.tgz` can stay; the next `make ansible-slurm` builds
on fresh servers anyway.

## 5. All make commands

Run from `~/workstation-/slurm` on the workstation. `make help` prints the same list.

| Command | What |
|---|---|
| `make init` | download the AWS provider |
| `make fmt` / `make validate` | format / check the Terraform code |
| `make key` | create `~/.ssh/slurm-dev-key` if missing (also done by `make plan`) |
| `make plan` | show what would change, save it to `terraform/tfplan` |
| `make apply` | apply the saved plan |
| `make destroy` | delete everything Terraform created |
| `make output` | IDs, IPs, NAT public IP |
| `make ssh [HOST=slurm-node-1] [SSH_ARGS=-X]` | log in to a Slurm server |
| `make inventory` | write `ansible/inventory.ini` from the Terraform outputs |
| `make ping` | check that Ansible can log in to every server |
| `make ansible-slurm [ARGS="--tags munge"]` | run the Slurm playbook (tags: base, packages, munge, build, slurmdbd, config, accounting, ssh, x11) |
