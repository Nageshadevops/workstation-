# Slurm Cluster: Manual Installation Guide (RHEL 9)

Copy-paste runbook. Read the **Index** first, then run the steps in order.
Every step has the same layout: **Goal · Run on · Doc · Commands · Expected**.

---

# INDEX

## 1. Big picture (what we are building, in plain words)

| # | Basic step | In one line |
|---|---|---|
| 1 | Prepare the admin box | Set up the workstation VM: tools, SSH shortcuts, build repos |
| 2 | Prepare the servers | Give the 4 Slurm VMs proper names, same time, enough memory |
| 3 | Same users everywhere | Create `munge` and `slurm` users with the same ID numbers on all servers |
| 4 | Authentication (MUNGE) | All servers share one secret key so they trust each other |
| 5 | Build Slurm | Turn the official Slurm source into install packages (RPMs) on the workstation |
| 6 | Install and configure Slurm | Install packages, write `slurm.conf`, start the services |
| 7 | Test | Run test jobs on the cluster |
| 8 | Accounting (later) | Add a database that records who ran which job |

## 2. Run sheet (actual steps)

Status: ✅ done and verified · ⏳ to do

| Step | What it does | Run on | Status |
|---|---|---|---|
| **PART A** | **[Workstation setup](#part-a-workstation-setup)** | | |
| [A1](#a1-launch-the-workstation-vm) | Launch the workstation VM in AWS console | AWS console | ✅ |
| [A2](#a2-log-in-to-the-workstation) | Log in to the workstation | laptop | ✅ |
| [A3](#a3-add-swap-on-the-workstation) | Add 2 GiB swap | workstation | ✅ |
| [A4](#a4-install-admin-tools) | Install git, make, jq, Terraform | workstation | ✅ |
| [A5](#a5-create-the-slurm-servers-with-terraform) | Create the 4 Slurm VMs with Terraform | workstation | ✅ |
| [A6](#a6-ssh-shortcuts-and-cluster-names) | SSH shortcuts + cluster names | workstation | ✅ |
| [A7](#a7-enable-the-crb-repo) | Enable CRB repo (for building Slurm) | workstation | ✅ |
| **PART B** | **[OS preparation on the 4 Slurm VMs](#part-b-os-preparation-on-the-slurm-vms)** | | |
| [B1](#b1-check-access-to-all-nodes) | Check SSH + sudo on all nodes | workstation | ✅ |
| [B2](#b2-set-the-hostnames) | Set hostnames | workstation (loop) | ✅ |
| [B3](#b3-add-cluster-names-to-the-hosts-file) | Add cluster names to `/etc/hosts` | workstation (loop) | ✅ |
| [B4](#b4-check-time-sync) | Check time sync | workstation (loop) | ✅ |
| [B5](#b5-add-swap-on-the-slurm-vms) | Add 2 GiB swap | workstation (loop) | ✅ |
| [B-CHECK](#b-check-verify-part-b) | Final check of Part B + SELinux/firewall state | workstation | ✅ |
| **PART C** | **[Users + MUNGE](#part-c-users-and-munge)** | | |
| [C1](#c1-create-the-munge-and-slurm-users) | Create `munge` + `slurm` users with fixed IDs | workstation (loop) | ✅ |
| [C2](#c2-install-munge) | Install MUNGE | workstation (loop) | ✅ |
| [C3](#c3-create-the-munge-key-on-slurm-master) | Create the MUNGE key on slurm-master | workstation | ✅ |
| [C4](#c4-copy-the-munge-key-to-the-compute-nodes) | Copy the key to the compute nodes | workstation (loop) | ✅ |
| [C5](#c5-start-munge) | Start MUNGE | workstation (loop) | ✅ |
| [C6](#c6-test-munge) | Test MUNGE locally and between nodes | workstation (loop) | ✅ |
| **PART D** | **[Build Slurm RPMs](#part-d-build-slurm-rpms-on-the-workstation)** | | |
| [D1](#d1-install-build-tools-and-libraries) | Install build tools + `-devel` libraries | workstation | ✅ |
| [D2](#d2-download-and-verify-the-slurm-source) | Download + verify the official Slurm tarball | workstation | ✅ |
| [D3](#d3-install-remaining-build-dependencies) | Install anything else the Slurm spec file needs | workstation | ✅ |
| [D4](#d4-build-the-rpms) | Build the RPMs (`rpmbuild -ta`) | workstation | ✅ |
| [D5](#d5-check-the-rpms) | Check the RPMs and the important plugins | workstation | ✅ |
| [D6](#d6-make-a-local-repo-and-copy-it-to-the-slurm-vms) | Make a local dnf repo, copy it to the 4 VMs | workstation (loop) | ✅ |
| **PART E** | **[Install and configure Slurm](#part-e-install-and-configure-slurm)** | | |
| [E1](#e1-install-the-slurm-packages) | Install Slurm packages (master: controller, nodes: compute) | workstation (loop) | ✅ |
| [E2](#e2-read-the-node-hardware) | Read node hardware (`slurmd -C`) + check cgroup v2 | workstation (loop) | ✅ |
| [E3](#e3-create-directories-and-log-rotation) | Create spool/log directories + log rotation | workstation (loop) | ✅ |
| [E4](#e4-write-the-config-files-on-the-workstation) | Write `slurm.conf` + `cgroup.conf` | workstation | ✅ |
| [E5](#e5-copy-the-config-files-to-all-vms) | Copy the config files to all 4 VMs | workstation (loop) | ✅ |
| [E6](#e6-start-slurmctld-on-slurm-master) | Start `slurmctld` on slurm-master | workstation | ✅ |
| [E7](#e7-start-slurmd-on-the-compute-nodes) | Start `slurmd` on the compute nodes | workstation (loop) | ✅ |
| [E8](#e8-check-the-cluster) | Check the cluster (`sinfo`) | workstation | ✅ |
| **PART F** | **[Test jobs](#part-f-test-jobs)** | | |
| [F1](#f1-interactive-job-with-srun) | Run a job with `srun` | slurm-master | ✅ |
| [F2](#f2-batch-job-with-sbatch) | Run a batch job with `sbatch` | slurm-master | ✅ |
| [F3](#f3-check-that-limits-work) | Check that CPU/memory limits are enforced | slurm-master | ✅ |
| **PART G** | **[Accounting: MariaDB + slurmdbd](#part-g-accounting-with-mariadb-and-slurmdbd)** | | |
| [G1](#g1-install-and-tune-mariadb) | Install MariaDB + small-memory tuning | slurm-master | ✅ |
| [G2](#g2-secure-mariadb) | Remove anonymous users + test database | slurm-master | ✅ |
| [G3](#g3-install-slurmdbd) | Install the `slurm-slurmdbd` package | slurm-master | ✅ |
| [G4](#g4-create-the-database-user-and-slurmdbdconf) | Create DB + DB user + `slurmdbd.conf` | slurm-master | ✅ |
| [G5](#g5-start-slurmdbd) | Start `slurmdbd` (+ G5b PID folder) | slurm-master | ✅ |
| [G6](#g6-switch-slurmconf-to-accounting) | Switch `slurm.conf` to accounting, copy to all VMs | workstation | ✅ |
| [G7](#g7-register-cluster-account-and-users) | Register cluster, account, users (`sacctmgr`) | slurm-master | ✅ |
| [G8](#g8-restart-slurm-to-use-accounting) | Restart slurmctld + slurmd | workstation | ✅ |
| [G9](#g9-test-accounting) | Test: `sacct`, invalid account rejected | slurm-master | ✅ |
| [G10](#g10-database-backup) | Nightly database backup | slurm-master | ✅ |
| **NEXT** | **[Open items before real production](#next-open-items-before-real-production)** | | |

## 3. Servers

| Name | Private IP | Type | Role | Created by |
|---|---|---|---|---|
| workstation-vm | 172.22.7.128 | t3.small | Admin box: Terraform, Slurm RPM build, Ansible (later), login node (later) | **Manual** (AWS console) |
| slurm-master | 172.21.10.116 | t3.micro | Controller (`slurmctld`); later `slurmdbd` + MariaDB | Terraform |
| slurm-node-1 | 172.21.10.30 | t3.micro | Compute (`slurmd`) | Terraform |
| slurm-node-2 | 172.21.10.127 | t3.micro | Compute (`slurmd`) | Terraform |
| slurm-node-3 | 172.21.10.238 | t3.micro | Compute (`slurmd`) | Terraform |

All servers: **Red Hat Enterprise Linux 9.8**, user `ec2-user`, time zone UTC.

## 4. Decisions

| Topic | Decision | Why |
|---|---|---|
| OS | RHEL 9 (Rocky Linux 9 works with the same commands) | Supported by Slurm, common in HPC |
| Slurm install method | Build official RPMs once on the workstation (`rpmbuild -ta`), install with `dnf` | Recommended by Quick Start Admin; distro/EPEL packages are not maintained by SchedMD |
| Slurm version | **23.11.11** (last release of the 23.11 series) | Project requirement: 23.x. Note: 23.11 no longer gets security fixes from SchedMD. Plan an upgrade later (the Upgrade Guide says how many releases can be skipped in one step) |
| Docs version | Read the **23.11 archive** docs: https://slurm.schedmd.com/archive/slurm-23.11.11/ | The main site shows the newest version (26.05); some options differ from 23.11 |
| MUNGE | From RHEL AppStream repo (`munge` 0.5.13) | Official Red Hat package, no extra repo needed |
| Extra repos | CRB on the workstation only. No EPEL | Keep servers clean and simple |
| Service users | `munge` UID/GID **2001**, `slurm` UID/GID **2002**, created **before** installing packages | Quick Start Admin: UIDs/GIDs must be the same on every server. If the package creates the user, the number can differ per server |
| SELinux | Keep **Enforcing** (RHEL default) | More secure. Slurm and MUNGE have no SELinux policy of their own, so systemd runs them unconfined and they work. If something is blocked: `sudo ausearch -m avc -ts recent` |
| Firewall | firewalld stays **off**; the AWS security group is the firewall | The security group already allows all traffic between Slurm VMs and only SSH from the workstation. If firewalld is turned on later, open 6817 (slurmctld), 6818 (slurmd), 6819 (slurmdbd) and the `SrunPortRange` |
| Accounting | Added **after** basic Slurm works | Quick Start Admin: *"defer adding accounting support until after basic Slurm functionality is established"* |
| Swap | 2 GiB swap file on every server, **jobs may not use it** (`AllowedSwapSpace=0` in cgroup.conf) | Test only: small instances. Swap is for the OS; jobs must stay inside their RAM limit. In production, size RAM properly |

## 5. Official documents

We install **23.11.11**, so use the **23.11 archive** of the docs (same pages, matching our version):

| Short name | Link (23.11.11) | Used for |
|---|---|---|
| Docs home (23.11.11) | https://slurm.schedmd.com/archive/slurm-23.11.11/ | Start page for all docs below |
| Quick Start Admin | https://slurm.schedmd.com/archive/slurm-23.11.11/quickstart_admin.html | Overall order of steps |
| Download | https://download.schedmd.com/slurm/ | Slurm source tarballs (all versions) |
| slurm.conf | https://slurm.schedmd.com/archive/slurm-23.11.11/slurm.conf.html | Main config file, every option |
| cgroup.conf | https://slurm.schedmd.com/archive/slurm-23.11.11/cgroup.conf.html | CPU/memory limits on compute nodes |
| Network | https://slurm.schedmd.com/archive/slurm-23.11.11/network.html | Ports used by Slurm |
| Accounting | https://slurm.schedmd.com/archive/slurm-23.11.11/accounting.html | slurmdbd + MariaDB (later) |
| Upgrade Guide | https://slurm.schedmd.com/upgrades.html | How to move to a newer version later |
| MUNGE | https://github.com/dun/munge/wiki/Installation-Guide | Authentication |

> If an archive link does not open, open the docs home link above and click the page name from there.

---

# PART A: Workstation setup

The workstation is created **manually** (not by Terraform). It is the only server you log in to from your laptop. All other servers are reached from here.

### A1. Launch the workstation VM

- **Goal:** create the admin VM.
- **Run on:** AWS console → EC2 → Launch instance

| Setting | Value |
|---|---|
| Name | `workstation-vm` |
| AMI | Red Hat Enterprise Linux 9 (x86_64) |
| Instance type | `t3.small` |
| Key pair | `workstation-pem-key` |
| Disk | 20 GiB gp3 |
| Security group | `workstation-sg`: inbound SSH (22) from **your own public IP only** |
| Public IP | Attach an **Elastic IP** (address stays the same after stop/start) |
| IAM role | Role with policy `workstation-slurm-terraform-policy` (lets Terraform create the Slurm VPC/VMs) |

### A2. Log in to the workstation

- **Run on:** your laptop

```bash
ssh -i workstation-pem-key.pem ec2-user@16.112.184.161
```

> "This system is not registered ... Unable to read consumer identity" is **normal on AWS**. Packages come from AWS RHUI repos; no registration needed.

### A3. Add swap on the workstation

- **Goal:** 2 GiB swap, so compiling Slurm does not run out of memory.
- **Run on:** workstation

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
free -h
```

- **Expected:** `Swap: 2.0Gi`

### A4. Install admin tools

- **Goal:** git, make, jq, Terraform.
- **Run on:** workstation

```bash
sudo dnf install -y git make jq dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y terraform
terraform -version
```

### A5. Create the Slurm servers with Terraform

- **Goal:** create VPC, subnets, NAT, security group and the 4 Slurm VMs.
- **Run on:** workstation, in `~/workstation-/slurm`

```bash
cd ~/workstation-/slurm
make init      # once: download the AWS provider
make plan      # creates ~/.ssh/slurm-dev-key if missing, shows what will be created
make apply     # creates everything
make output    # shows the private IPs
```

> If the IPs change after a re-create, update them in A6, B3 and the Servers table.

### A6. SSH shortcuts and cluster names

- **Goal:** type `ssh slurm-node-1` instead of the full command; workstation knows the cluster names.
- **Run on:** workstation

First check it was not done already (no output = not done, continue):

```bash
grep -n 'slurm-master' ~/.ssh/config /etc/hosts
```

**A6a. SSH shortcuts:**

```bash
cat >> ~/.ssh/config <<'EOF'
Host slurm-master
    HostName 172.21.10.116
Host slurm-node-1
    HostName 172.21.10.30
Host slurm-node-2
    HostName 172.21.10.127
Host slurm-node-3
    HostName 172.21.10.238
Host slurm-master slurm-node-1 slurm-node-2 slurm-node-3
    User ec2-user
    IdentityFile ~/.ssh/slurm-dev-key
    StrictHostKeyChecking accept-new
EOF
chmod 600 ~/.ssh/config
```

**A6b. Cluster names in `/etc/hosts`:**

```bash
sudo tee -a /etc/hosts <<'EOF'
# ---- Slurm cluster ----
172.21.10.116  slurm-master
172.21.10.30   slurm-node-1
172.21.10.127  slurm-node-2
172.21.10.238  slurm-node-3
EOF
```

- **Check:**

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do ssh $n hostname; done
```

> Run A6a and A6b only **once**; running again adds duplicate lines.

### A7. Enable the CRB repo

- **Goal:** make `munge-devel` (and other `-devel` build libraries) available on the workstation.
- **Run on:** workstation only (the Slurm servers do not need CRB)
- **Doc:** Quick Start Admin → *Installing Prerequisites*: Slurm needs `-devel` libraries to build its plugins; `auth/munge` needs MUNGE's development library.

Found before this step:
- `munge`, `munge-libs` 0.5.13 are in `rhel-9-appstream-rhui-rpms`
- `munge-devel` gives "No matching Packages" (it is in CRB, which is disabled)

```bash
sudo dnf config-manager --set-enabled codeready-builder-for-rhel-9-rhui-rpms
sudo dnf info munge-devel 2>&1 | grep -E '^(Name|Version|Repository)|No matching'
```

- **Expected:** `Name : munge-devel`, `Version : 0.5.13`, `Repository : codeready-builder-for-rhel-9-rhui-rpms`

---

# PART B: OS preparation on the Slurm VMs

> **Rule for all `for n in slurm-...` loops in this guide:** run them **on the workstation only**. The Slurm VMs have no SSH key for each other, so a loop started on slurm-master fails with `Permission denied (publickey,...)` (nothing is changed in that case).

All Part B commands run **on the workstation**. Each loop logs in to the 4 VMs and does the work there, so one paste covers all of them.
(If you prefer to work inside one VM, open the "inside one VM" section under the step.)

### B1. Check access to all nodes

- **Goal:** confirm SSH and sudo work on all 4 VMs.
- **Run on:** workstation (needs A6)

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "========== $n =========="
  ssh $n 'hostname; cat /etc/redhat-release; nproc; free -h; sudo -n true && echo "SUDO OK"'
done
```

- **Expected per node:** RHEL 9.8, 2 CPUs, `SUDO OK`.

### B2. Set the hostnames

- **Goal:** each VM's short hostname = its Slurm node name.
- **Run on:** workstation
- **Doc:** Quick Start Admin → *Configuration*: *"NodeHostname is the name returned by the command `/bin/hostname -s`."*
- `preserve_hostname: true` stops AWS cloud-init from resetting the name after a reboot.

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  ssh $n "sudo hostnamectl set-hostname $n &&
          echo 'preserve_hostname: true' | sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg >/dev/null &&
          hostname"
done
```

- **Expected:** prints `slurm-master`, `slurm-node-1`, `slurm-node-2`, `slurm-node-3`.

<details><summary>Inside one VM instead</summary>

```bash
sudo hostnamectl set-hostname slurm-master     # use this VM's own name
echo 'preserve_hostname: true' | sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg
```
</details>

### B3. Add cluster names to the hosts file

- **Goal:** every VM resolves every other VM by name, the same way.
- **Run on:** workstation (safe to re-run; skips VMs that already have the entries)

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'grep -q "Slurm cluster" /etc/hosts || sudo tee -a /etc/hosts >/dev/null' <<'EOF'
# ---- Slurm cluster ----
172.21.10.116  slurm-master
172.21.10.30   slurm-node-1
172.21.10.127  slurm-node-2
172.21.10.238  slurm-node-3
EOF
  ssh $n 'for h in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
            echo "  $h -> $(getent ahostsv4 $h | head -1 | cut -d" " -f1)"
          done'
done
```

- **Expected:** on every VM, all 4 names show their `172.21.10.x` address.

> Note: `getent hosts <own-name>` may show an IPv6 `fe80::...` address for the VM's **own** name. This is normal on RHEL (systemd "myhostname"). Slurm uses IPv4 by default, so it is not a problem. That is why the check above uses `ahostsv4` (IPv4 only).

<details><summary>Inside one VM instead (run once only)</summary>

```bash
sudo tee -a /etc/hosts <<'EOF'
# ---- Slurm cluster ----
172.21.10.116  slurm-master
172.21.10.30   slurm-node-1
172.21.10.127  slurm-node-2
172.21.10.238  slurm-node-3
EOF
```
</details>

### B4. Check time sync

- **Goal:** all clocks are synchronized (MUNGE rejects credentials if clocks differ).
- **Run on:** workstation
- **Doc:** Quick Start Admin → *Super Quick Start*, item 1: *"Make sure the clocks ... are synchronized across the cluster."*
- RHEL on AWS already runs `chronyd` with Amazon Time Sync (`169.254.169.123`). We only check.

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'systemctl is-active chronyd
          chronyc tracking | grep -E "Reference ID|Leap status"
          timedatectl | grep -E "Time zone|synchronized"'
done
```

- **Expected:** `active`, `Reference ID ... (169.254.169.123)`, `Leap status : Normal`, `Time zone: UTC`, `System clock synchronized: yes`.

### B5. Add swap on the Slurm VMs

- **Goal:** 2 GiB swap on each VM (test only; small instances).
- **Run on:** workstation (safe to re-run; skips VMs that already have `/swapfile`)

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n '[ -f /swapfile ] || {
            sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none &&
            sudo chmod 600 /swapfile &&
            sudo mkswap /swapfile >/dev/null &&
            sudo swapon /swapfile &&
            echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null; }
          free -h | grep Swap'
done
```

- **Expected:** `Swap: 2.0Gi` on every VM.

<details><summary>Inside one VM instead</summary>

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
free -h
```
</details>

### B-CHECK. Verify Part B

- **Goal:** one final check of everything in Part B, plus the SELinux and firewall state (needed for Part C).
- **Run on:** workstation

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "========== $n =========="
  ssh $n 'echo "hostname : $(hostname -s)"
          echo "master   : $(getent ahostsv4 slurm-master | head -1 | cut -d" " -f1)"
          echo "time     : $(chronyc tracking | grep "Leap status")"
          echo "swap     : $(free -h | grep Swap)"
          echo "SELinux  : $(getenforce)"
          echo "firewalld: $(systemctl is-active firewalld)"'
done
```

- **Expected per VM:** own name, `master : 172.21.10.116`, `Leap status : Normal`, `Swap: 2.0Gi`. Note the SELinux and firewalld values.

---

# PART C: Users and MUNGE

**What is MUNGE?** Every Slurm message between servers is signed with MUNGE. All servers share one secret file, `/etc/munge/munge.key`. A server accepts a message only if it was signed with the same key and the clocks match (B4).

**Doc:** Quick Start Admin → *Super Quick Start*:
- *"Make sure the clocks, users and groups (UIDs and GIDs) are synchronized across the cluster."*
- *"Install MUNGE for authentication. Make sure that all nodes in your cluster have the same munge.key. Make sure the MUNGE daemon, munged, is started before you start the Slurm daemons."*
- *"The SlurmUser must exist prior to starting Slurm and must exist on all nodes of the cluster."*

MUNGE guide: https://github.com/dun/munge/wiki/Installation-Guide

### C1. Create the munge and slurm users

- **Goal:** same user names **and** same ID numbers on every server.
- **Run on:** workstation
- **Why before C2:** if we let `dnf install munge` create the user, each server picks its own free number, and the numbers can differ.

**C1a. Check that the names and numbers are free:**

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'getent passwd munge slurm 2001 2002; getent group munge slurm 2001 2002; echo "   (nothing above = OK)"'
done
```

- **Expected:** only `(nothing above = OK)` for every VM. If something is printed, stop and ask before continuing.

**C1b. Create the users:**

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'sudo groupadd -r -g 2001 munge &&
          sudo useradd  -r -u 2001 -g munge -d /var/lib/munge -s /sbin/nologin -c "MUNGE authentication" munge &&
          sudo groupadd -r -g 2002 slurm &&
          sudo useradd  -r -u 2002 -g slurm -d /var/lib/slurm -s /sbin/nologin -c "Slurm workload manager" slurm
          id munge; id slurm'
done
```

- **Expected on every VM:**
  ```
  uid=2001(munge) gid=2001(munge) groups=2001(munge)
  uid=2002(slurm) gid=2002(slurm) groups=2002(slurm)
  ```
- `-r` = system account, `-s /sbin/nologin` = nobody can log in as this user.

### C2. Install MUNGE

- **Goal:** install `munge` from the RHEL AppStream repo.
- **Run on:** workstation

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'sudo dnf install -y munge munge-libs && rpm -q munge munge-libs && id munge'
done
```

- **Expected:** `Complete!`, then `munge-0.5.13-...`, `munge-libs-0.5.13-...`, and still `uid=2001(munge) gid=2001(munge)` (the package used our user, it did not make a new one).
- `dnf install` = installs the package from the Red Hat repo (checks the Red Hat GPG signature, pulls dependencies).
  `rpm -q` = only **checks** what is installed. It installs nothing.
- Quick Start Admin → *Handling Dependencies*: *"we recommend avoiding low-level commands like dpkg and rpm, and instead using high-level commands like dnf and apt"*. So we always **install** with `dnf`, never with `rpm -i`.

### C3. Create the MUNGE key on slurm-master

- **Goal:** create **one** secret key. slurm-master holds the original; the others get a copy in C4.
- **Run on:** workstation
- **Doc:** MUNGE Installation Guide → *Creating a secret key*: 1024 random bytes, owned by `munge`, mode `0400`.

```bash
ssh slurm-master '
  if sudo test -f /etc/munge/munge.key; then
    echo "Key already exists: keeping it"
  else
    sudo dd if=/dev/urandom of=/etc/munge/munge.key bs=1 count=1024 status=none
    echo "New key created"
  fi
  sudo chown munge:munge /etc/munge/munge.key
  sudo chmod 400 /etc/munge/munge.key
  sudo restorecon /etc/munge/munge.key
  sudo ls -l /etc/munge/munge.key'
```

- **Expected:** `-r-------- 1 munge munge 1024 ... /etc/munge/munge.key`

> **Security:** the key is a password for the whole cluster. Never put it in Git, email or chat. Store a backup copy only in a safe place (for example AWS Secrets Manager).

### C4. Copy the MUNGE key to the compute nodes

- **Goal:** all servers have the **same** key.
- **Run on:** workstation
- The key is streamed master → workstation → node through SSH. It is **not** saved on the workstation disk.

```bash
for n in slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh slurm-master 'sudo cat /etc/munge/munge.key' |
    ssh $n 'sudo tee /etc/munge/munge.key >/dev/null &&
            sudo chown munge:munge /etc/munge/munge.key &&
            sudo chmod 400 /etc/munge/munge.key &&
            sudo restorecon /etc/munge/munge.key &&
            sudo ls -l /etc/munge/munge.key'
done
```

**Check that all keys are identical** (compare checksums; the key itself is not shown):

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "$n  $(ssh $n 'sudo sha256sum /etc/munge/munge.key' | cut -c1-16)"
done
```

- **Expected:** the same 16 characters on all 4 lines.

### C5. Start MUNGE

- **Goal:** `munge` service running now and after every reboot.
- **Run on:** workstation

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'sudo systemctl enable --now munge; systemctl is-active munge; systemctl is-enabled munge'
done
```

- **Expected:** `active` and `enabled` on every VM.
- If not active: `ssh slurm-node-1 'sudo journalctl -u munge -n 20 --no-pager'`

### C6. Test MUNGE

- **Goal:** prove that each server can check credentials made on itself and on slurm-master.
- **Run on:** workstation
- **Doc:** MUNGE Installation Guide → *Testing the installation*.

**C6a. Local test (each VM signs and checks its own credential):**

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n  $(ssh $n 'munge -n | unmunge | grep STATUS')"
done
```

**C6b. Cross test (credential made on slurm-master, checked on each node):**

```bash
for n in slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== slurm-master -> $n"
  ssh slurm-master 'munge -n' | ssh $n 'unmunge | grep -E "STATUS|ENCODE_HOST"'
done
```

- **Expected:** `STATUS: Success (0)` everywhere; in C6b `ENCODE_HOST: slurm-master`.
- If you see `Invalid credential`: keys differ, so repeat C4. If you see `Expired credential` or `Rewound credential`: clocks differ, so check B4.

# PART D: Build Slurm RPMs on the workstation

**What happens here:** Red Hat does not ship Slurm. We take the official source from SchedMD and turn it into RPM packages **once**, on the workstation. Then every VM installs those packages with `dnf`.

**Doc:** Quick Start Admin → *Installing Prerequisites* (which library enables which plugin) and *Building RPMs* (`rpmbuild -ta`).

**Rules:**
- Build as `ec2-user`, **not root** (normal practice for rpmbuild).
- Slurm finds optional libraries automatically while building. **A plugin is only built if its `-devel` library is installed before the build.** That is why D1 comes first.
- Version used: **23.11.11**. To use another version later, change only the `SLURM_VER` line.
- D2–D5 use the variable `SLURM_VER`. If you open a new SSH session in between, first run: `SLURM_VER=23.11.11`

### D1. Install build tools and libraries

- **Goal:** compiler, rpmbuild, and the libraries for the plugins we need.
- **Run on:** workstation (needs A7: CRB enabled)

| Package | Gives Slurm | From the Quick Start "Prerequisites" table |
|---|---|---|
| `munge-devel` | `auth/munge` (authentication) | auth/munge → MUNGE |
| `mariadb-connector-c-devel` | `accounting_storage/mysql` (slurmdbd, Part G) | accounting_storage/mysql → MySQL or MariaDB |
| `hwloc-devel` | `task/cgroup` | task/cgroup → hwloc |
| `dbus-devel`, `kernel-headers` | cgroup v2 support (RHEL 9 uses cgroup v2) | task/cgroup → bpf, dbus (cgroup/v2) |
| `numactl-devel` | NUMA support in `task/affinity` | NUMA → numa |
| `pam-devel` | PAM support (`pam_slurm`) | PAM support → PAM |
| `readline-devel` | arrow keys/history in `scontrol`, `sacctmgr` | Readline support → readline |
| `lua-devel` | Lua job-submit plugins | Lua API → lua |
| `json-c-devel` | JSON output (`--json`) | — |

```bash
sudo dnf install -y rpm-build gcc make perl perl-ExtUtils-MakeMaker perl-devel python3 bzip2 wget createrepo_c \
  munge-devel munge-libs mariadb-connector-c-devel \
  hwloc-devel dbus-devel kernel-headers numactl-devel \
  pam-devel readline-devel lua-devel json-c-devel
```

- **Expected:** `Complete!` and no `No match for argument` errors.

### D2. Download and verify the Slurm source

- **Goal:** get the official tarball and prove it is the genuine, complete file.
- **Run on:** workstation
- **Source:** SchedMD's official download server https://download.schedmd.com/slurm/ (HTTPS). It keeps every old version.

```bash
SLURM_VER=23.11.11

mkdir -p ~/slurm-build && cd ~/slurm-build
wget -nc https://download.schedmd.com/slurm/slurm-${SLURM_VER}.tar.bz2
ls -l slurm-${SLURM_VER}.tar.bz2
tar -tjf slurm-${SLURM_VER}.tar.bz2 > /dev/null && echo "ARCHIVE OK"
sha256sum slurm-${SLURM_VER}.tar.bz2
```

- **Expected:** file size several MB, `ARCHIVE OK`, and a SHA-256 checksum.
- **Record the checksum** in the line below. Every later build (Ansible too) must check against this same value, so all builds use the identical file:

```
slurm-23.11.11.tar.bz2  SHA-256: 4a1713dceb5bfad74d3f43c9bfedf23603933f0d7148cdad7feedea57da4e45d
```

- Later downloads are checked with (must say `slurm-23.11.11.tar.bz2: OK`):

```bash
echo "4a1713dceb5bfad74d3f43c9bfedf23603933f0d7148cdad7feedea57da4e45d  slurm-23.11.11.tar.bz2" | sha256sum -c -
```

### D3. Install remaining build dependencies

- **Goal:** let `dnf` read Slurm's own spec file and install anything still missing.
- **Run on:** workstation (same shell as D2, so `SLURM_VER` is set)

```bash
cd ~/slurm-build
tar -xjf slurm-${SLURM_VER}.tar.bz2 slurm-${SLURM_VER}/slurm.spec
sudo dnf builddep -y slurm-${SLURM_VER}/slurm.spec
```

- **Expected:** `Complete!` or `Nothing to do.`

### D4. Build the RPMs

- **Goal:** turn the source into RPM packages.
- **Run on:** workstation, as `ec2-user` (no sudo)
- **Doc:** Quick Start Admin → *Building RPMs*: `rpmbuild -ta slurm-<version>.tar.bz2`
- Takes about **15–30 minutes** on a t3.small. It runs in the background (`nohup`), so it keeps running even if your SSH connection drops.

```bash
cd ~/slurm-build
nohup rpmbuild -ta slurm-${SLURM_VER}.tar.bz2 > ~/slurm-build/build.log 2>&1 &
tail -f ~/slurm-build/build.log
```

- Press **Ctrl+C** to stop watching the log (the build keeps running).
- **Finished** when the log ends with `+ exit 0`. Check with:

```bash
tail -3 ~/slurm-build/build.log
```

- If it failed: `grep -iE 'error|failed build dependencies' ~/slurm-build/build.log | head -20` and fix that first.

### D5. Check the RPMs

- **Goal:** the packages exist, and the important plugins were built.
- **Run on:** workstation

```bash
ls -1 ~/rpmbuild/RPMS/x86_64/

R=~/rpmbuild/RPMS/x86_64
echo "--- auth/munge, cgroup v2, task/cgroup (package: slurm)"
rpm -qlp $R/slurm-${SLURM_VER}-*.rpm | grep -E 'auth_munge\.so|cgroup_v2\.so|task_cgroup\.so'
echo "--- accounting_storage/mysql (package: slurm-slurmdbd)"
rpm -qlp $R/slurm-slurmdbd-${SLURM_VER}-*.rpm | grep -E 'accounting_storage_mysql\.so'
```

- **Expected:** a list of `slurm-*-23.11.11-1.el9.x86_64.rpm` files, including `slurm-`, `slurm-slurmctld-`, `slurm-slurmd-`, `slurm-slurmdbd-`, `slurm-perlapi-`, `slurm-pam_slurm-` …
- And these 4 plugin files are listed: `auth_munge.so`, `cgroup_v2.so`, `task_cgroup.so`, `accounting_storage_mysql.so`.
- If a plugin is missing: its `-devel` package was not installed before the build. Install it, delete `~/rpmbuild/RPMS`, and repeat D4.

**Result of our build (13 RPMs) and where each one goes:**

| RPM | What it is | workstation (login) | slurm-master | slurm-node-1..3 |
|---|---|---|---|---|
| `slurm` | Base: commands (`sinfo`, `srun`, `sbatch`…), libraries, plugins | later | ✅ | ✅ |
| `slurm-perlapi` | Perl API (needed by some commands, e.g. `seff`) | later | ✅ | ✅ |
| `slurm-slurmctld` | Controller daemon | | ✅ | |
| `slurm-slurmd` | Compute daemon | | | ✅ |
| `slurm-slurmdbd` | Accounting daemon (Part G) | | ✅ (Part G) | |
| `slurm-pam_slurm` | PAM module: block SSH to nodes without a job (optional) | | | optional |
| `slurm-contribs` | Extra tools (`seff`, `sjobexitmod`…) | optional | optional | |
| `slurm-libpmi` | PMI library for MPI programs | | | when MPI is used |
| `slurm-devel` | Header files to build software against Slurm | | | |
| `slurm-example-configs` | Example config files | | reference only | |
| `slurm-sackd` | Auth daemon for `auth/slurm` (we use MUNGE instead) | | | |
| `slurm-torque`, `slurm-openlava` | Wrappers for old PBS/LSF commands | | | |

This follows the Quick Start Admin → *Installing Packages* table (`slurm`, `slurm-perlapi`, `slurm-slurmctld`, `slurm-slurmd`, `slurm-slurmdbd`).

### D6. Make a local repo and copy it to the Slurm VMs

- **Goal:** every VM can install Slurm with `dnf install`, from its own local copy.
- **Run on:** workstation
- Why `gpgcheck=0`: we built these RPMs ourselves, so they have no Red Hat signature. The trust comes from the checksum check in D2. (Large production sites sign their own RPMs and host the repo on an internal web server or S3.)

**D6a. Create the repo on the workstation:**

```bash
rm -rf ~/slurm-repo && mkdir -p ~/slurm-repo
cp ~/rpmbuild/RPMS/x86_64/*.rpm ~/slurm-repo/
createrepo_c ~/slurm-repo
ls ~/slurm-repo
```

**D6b. Copy it to the 4 VMs and register it with dnf:**

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  scp -rq ~/slurm-repo $n:/tmp/ &&
  ssh $n 'sudo rm -rf /opt/slurm-repo &&
          sudo mv /tmp/slurm-repo /opt/slurm-repo &&
          sudo chown -R root:root /opt/slurm-repo &&
          sudo restorecon -R /opt/slurm-repo &&
          printf "[slurm-local]\nname=Slurm local repo (built on workstation)\nbaseurl=file:///opt/slurm-repo\nenabled=1\ngpgcheck=0\n" |
            sudo tee /etc/yum.repos.d/slurm-local.repo >/dev/null &&
          sudo dnf -q --disablerepo="*" --enablerepo=slurm-local makecache &&
          dnf -q --disablerepo="*" --enablerepo=slurm-local list available "slurm*" | head -5'
done
```

- **Expected:** for every VM, a few lines like `slurm.x86_64  23.11.11-1.el9  slurm-local`.
- Nothing is installed yet. That is Part E.

# PART E: Install and configure Slurm

**What happens here:** install the packages from our local repo, describe the cluster in `slurm.conf`, copy the **same** config to every VM, then start the daemons.

**Doc (23.11.11):** Quick Start Admin → *Installing Packages*, *Configuration*, *Starting the Daemons*; slurm.conf and cgroup.conf man pages (links in the Index).

| Daemon | Runs on | Runs as | Port |
|---|---|---|---|
| `slurmctld` (controller) | slurm-master | `slurm` user | 6817 |
| `slurmd` (compute) | slurm-node-1..3 | `root` (must start jobs as other users) | 6818 |

### E1. Install the Slurm packages

- **Goal:** controller packages on slurm-master, compute packages on the nodes.
- **Run on:** workstation
- **Doc:** Quick Start Admin → *Installing Packages* table.

```bash
echo "== slurm-master"
ssh slurm-master 'sudo dnf install -y slurm slurm-perlapi slurm-slurmctld && rpm -q slurm slurm-perlapi slurm-slurmctld'

for n in slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'sudo dnf install -y slurm slurm-perlapi slurm-slurmd && rpm -q slurm slurm-perlapi slurm-slurmd'
done
```

- **Expected:** `Complete!`, then the 3 package names with `23.11.11-1.el9` on each VM.
- Daemons are **not** started yet (no config file yet).

### E2. Read the node hardware

- **Goal:** get the exact CPU and memory values for the `NodeName=` line in `slurm.conf`, and confirm cgroup v2.
- **Run on:** workstation
- **Doc:** slurmd man page: `slurmd -C` *"Print actual hardware configuration and exit. The format of output is the same as used in slurm.conf"*.

```bash
for n in slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'slurmd -C | head -1; echo "cgroup fs: $(stat -fc %T /sys/fs/cgroup)"'
done
```

- **Expected (t3.micro):**
  ```
  NodeName=slurm-node-1 CPUs=2 Boards=1 SocketsPerBoard=1 CoresPerSocket=1 ThreadsPerCore=2 RealMemory=717
  cgroup fs: cgroup2fs
  ```
- `cgroup2fs` = cgroup v2 (RHEL 9 default), which matches `CgroupPlugin=cgroup/v2` in E4.
- If your values differ from the expected ones, change the `NodeName=` line in E4 to match **before** E4.

### E3. Create directories and log rotation

- **Goal:** create the folders Slurm writes to. Slurm does **not** create them itself.
- **Run on:** workstation
- **Doc:** Quick Start Admin: *"The parent directories for Slurm's log files, process ID files, state save directories, etc. are not created by Slurm. They must be created and made writable by SlurmUser as needed prior to starting Slurm daemons."*

| Folder | VM | Owner | Used for |
|---|---|---|---|
| `/var/spool/slurmctld` | slurm-master | slurm | `StateSaveLocation`: job and node state (survives restarts) |
| `/var/spool/slurmd` | nodes | root | `SlurmdSpoolDir`: job scripts on the node |
| `/var/log/slurm` | all | slurm (master) / root (nodes) | log files |

```bash
echo "== slurm-master"
ssh slurm-master 'sudo install -d -o slurm -g slurm -m 755 /var/spool/slurmctld /var/log/slurm &&
                  ls -ld /var/spool/slurmctld /var/log/slurm'

for n in slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'sudo install -d -o root -g root -m 755 /var/spool/slurmd /var/log/slurm &&
          ls -ld /var/spool/slurmd /var/log/slurm'
done
```

**Log rotation** (so logs do not fill the disk; production must-have):

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'printf "/var/log/slurm/*.log {\n    weekly\n    rotate 8\n    compress\n    missingok\n    notifempty\n    copytruncate\n}\n" |
            sudo tee /etc/logrotate.d/slurm >/dev/null && sudo logrotate -d /etc/logrotate.d/slurm 2>&1 | tail -1'
done
```

- **Expected:** folders listed with the right owner; logrotate prints a line without `error`.

### E4. Write the config files on the workstation

- **Goal:** one `slurm.conf` and one `cgroup.conf`, kept on the workstation as the **master copy**. Every VM gets an identical copy (E5).
- **Run on:** workstation
- **Doc:** Quick Start Admin → *Configuration*: *"This configuration file must be available on each node of the cluster and must have consistent contents."* Every option is explained in the slurm.conf man page.

**E4a. `slurm.conf`:**

```bash
mkdir -p ~/slurm-config
cat > ~/slurm-config/slurm.conf <<'EOF'
# =====================================================================
# slurm.conf - Slurm 23.11.11
# Master copy: workstation ~/slurm-config/slurm.conf
# Same file on every VM: /etc/slurm/slurm.conf
# Docs: https://slurm.schedmd.com/archive/slurm-23.11.11/slurm.conf.html
# =====================================================================

# ---- Cluster and controller ----
ClusterName=slurmdev
SlurmctldHost=slurm-master(172.21.10.116)

# ---- Users and authentication (Part C) ----
SlurmUser=slurm
AuthType=auth/munge
CredType=cred/munge

# ---- Ports (AWS security group allows all traffic between Slurm VMs) ----
SlurmctldPort=6817
SlurmdPort=6818

# ---- State and spool folders (created in E3) ----
StateSaveLocation=/var/spool/slurmctld
SlurmdSpoolDir=/var/spool/slurmd

# ---- Logging (rotated by /etc/logrotate.d/slurm) ----
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log
SlurmctldDebug=info
SlurmdDebug=info

# ---- Process tracking and limits (uses cgroup.conf) ----
ProctrackType=proctrack/cgroup
TaskPlugin=task/cgroup,task/affinity
JobAcctGatherType=jobacct_gather/cgroup

# ---- Scheduling ----
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# ---- Timers ----
SlurmctldTimeout=120
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0

# ---- A node that was DOWN comes back automatically when slurmd is healthy ----
ReturnToService=1

# ---- MPI ----
MpiDefault=none

# ---- Accounting: none for now; Part G switches this to slurmdbd ----
AccountingStorageType=accounting_storage/none
JobCompType=jobcomp/none

# ---- Compute nodes (values from E2 "slurmd -C") ----
# RealMemory is set a bit below the real 717 MB to keep memory for the OS.
NodeName=slurm-node-[1-3] CPUs=2 Boards=1 SocketsPerBoard=1 CoresPerSocket=1 ThreadsPerCore=2 RealMemory=600 State=UNKNOWN

# ---- Partitions (queues) ----
PartitionName=batch Nodes=slurm-node-[1-3] Default=YES DefaultTime=01:00:00 MaxTime=1-00:00:00 DefMemPerCPU=250 State=UP
EOF
```

What the main lines mean (details in the slurm.conf man page):

| Line | Meaning |
|---|---|
| `SlurmctldHost=slurm-master(172.21.10.116)` | Name and address of the controller |
| `SelectType=select/cons_tres` + `CR_Core_Memory` | Jobs get whole CPU **cores** and a fixed amount of **memory**; several jobs can share a node. Recommended by the Quick Start (*Resource selection*) |
| `ProctrackType`, `TaskPlugin`, `JobAcctGatherType` = cgroup | Slurm tracks and limits each job with Linux cgroups (settings in `cgroup.conf`) |
| `SchedulerType=sched/backfill` | Small jobs may start early if they do not delay bigger jobs. Needs time limits, which is why the partition has `DefaultTime` and `MaxTime` |
| `RealMemory=600` | Memory (MB) Slurm may give to jobs on each node. Must be ≤ the value from `slurmd -C`, else the node is marked invalid |
| `DefMemPerCPU=250` | Memory per CPU for a job that does not ask for memory (`--mem`) |
| `ReturnToService=1` | A node that went DOWN because it did not respond becomes usable again by itself once it responds |

> t3.micro has 1 core with 2 threads (`ThreadsPerCore=2`). With `CR_Core_Memory` one job gets the whole core (= 2 CPUs), so **one job per node at a time**. On bigger servers with more cores, more jobs fit.

**E4b. `cgroup.conf`:**

```bash
cat > ~/slurm-config/cgroup.conf <<'EOF'
# =====================================================================
# cgroup.conf - Slurm 23.11.11
# Docs: https://slurm.schedmd.com/archive/slurm-23.11.11/cgroup.conf.html
# =====================================================================
CgroupPlugin=cgroup/v2
ConstrainCores=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=yes
AllowedSwapSpace=0
ConstrainDevices=yes
EOF
```

| Line | Meaning |
|---|---|
| `CgroupPlugin=cgroup/v2` | RHEL 9 uses cgroup v2 (checked in E2) |
| `ConstrainCores=yes` | A job can only use the CPUs it was given |
| `ConstrainRAMSpace=yes` | A job may use only the RAM it asked for |
| `ConstrainSwapSpace=yes` + `AllowedSwapSpace=0` | A job may **not** use swap. Without this, a job that goes over its RAM limit just moves into swap and is **not** stopped (found in F3). Swap stays available for the OS |
| `ConstrainDevices=yes` | A job can only use the devices (e.g. GPUs) it was given |

> After changing `cgroup.conf`: run E5 (copy), then restart slurmd on the nodes: `for n in slurm-node-1 slurm-node-2 slurm-node-3; do ssh $n 'sudo systemctl restart slurmd'; done`

### E5. Copy the config files to all VMs

- **Goal:** identical `/etc/slurm/slurm.conf` and `/etc/slurm/cgroup.conf` on all 4 VMs.
- **Run on:** workstation
- Files are owned by root, mode 644 (readable by everyone, as the slurm.conf man page expects; it holds no secrets).

```bash
for n in slurm-master slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  scp -q ~/slurm-config/slurm.conf ~/slurm-config/cgroup.conf $n:/tmp/ &&
  ssh $n 'sudo install -D -o root -g root -m 644 /tmp/slurm.conf  /etc/slurm/slurm.conf &&
          sudo install -D -o root -g root -m 644 /tmp/cgroup.conf /etc/slurm/cgroup.conf &&
          rm -f /tmp/slurm.conf /tmp/cgroup.conf &&
          sudo restorecon -R /etc/slurm &&
          echo "slurm.conf $(sha256sum /etc/slurm/slurm.conf | cut -c1-16)  cgroup.conf $(sha256sum /etc/slurm/cgroup.conf | cut -c1-16)"'
done
```

- **Expected:** the **same** two checksums on all 4 VMs.
- **Whenever you change the config later:** edit the file on the workstation, run E5 again, then `ssh slurm-master 'sudo scontrol reconfigure'`.

### E6. Start slurmctld on slurm-master

- **Goal:** start the controller.
- **Run on:** workstation
- **Doc:** Quick Start Admin → *Super Quick Start*: *"systemctl enable slurmctld"* and *"Start the slurmctld and slurmd daemons."*

```bash
ssh slurm-master 'sudo systemctl enable --now slurmctld; sleep 3
                  systemctl is-active slurmctld
                  scontrol ping
                  sudo tail -5 /var/log/slurm/slurmctld.log'
```

- **Expected:** `active` and `Slurmctld(primary) at slurm-master is UP`.
- If not active: `ssh slurm-master 'sudo journalctl -u slurmctld -n 30 --no-pager; sudo tail -30 /var/log/slurm/slurmctld.log'`

### E7. Start slurmd on the compute nodes

- **Goal:** start the compute daemon on each node.
- **Run on:** workstation

```bash
for n in slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n"
  ssh $n 'sudo systemctl enable --now slurmd; sleep 2
          systemctl is-active slurmd
          sudo tail -3 /var/log/slurm/slurmd.log'
done
```

- **Expected:** `active` on each node; the log shows `slurmd started` (no `error`).
- If not active: `ssh slurm-node-1 'sudo journalctl -u slurmd -n 30 --no-pager; sudo tail -30 /var/log/slurm/slurmd.log'`

### E8. Check the cluster

- **Goal:** the controller sees all 3 nodes as ready.
- **Run on:** workstation

```bash
ssh slurm-master 'sinfo; echo; sinfo -N -l; echo; scontrol show node slurm-node-1 | grep -E "State|CPUTot|RealMemory|Reason"'
```

- **Expected:**
  ```
  PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
  batch*       up 1-00:00:00      3   idle slurm-node-[1-3]
  ```
- If a node shows `down`, `drain` or `inval`: look at `Reason=` in the output.
  - `Low RealMemory` → `RealMemory` in E4 is bigger than the node has. Lower it, run E5, then `sudo scontrol reconfigure` on master.
  - After fixing, bring it back: `ssh slurm-master 'sudo scontrol update nodename=slurm-node-[1-3] state=resume'`

---

# PART F: Test jobs

All tests run **as `ec2-user` on slurm-master** (log in with `ssh slurm-master`).
Job users must exist on every node with the same UID. `ec2-user` (UID 1000) exists on all VMs from the AWS image, so it can run jobs right away.

**Doc:** Quick Start User Guide https://slurm.schedmd.com/archive/slurm-23.11.11/quickstart.html

### F1. Interactive job with srun

- **Goal:** run a command on the compute nodes.
- **Run on:** slurm-master

```bash
srun -N3 hostname
srun -N1 --mem=100M -t 5 bash -c 'echo "I am $(whoami) on $(hostname), CPUs: $(nproc)"'
```

- **Expected:** the 3 node names (any order), then one line from a node.

### F2. Batch job with sbatch

- **Goal:** submit a job script, watch it in the queue, read its output.
- **Run on:** slurm-master

```bash
cat > ~/test-job.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=100M
#SBATCH --time=00:05:00
#SBATCH --output=test-%j.out

echo "Job $SLURM_JOB_ID on $(hostname) started $(date)"
sleep 30
echo "Done $(date)"
EOF

sbatch ~/test-job.sh
squeue
```

> Always submit with `sbatch`. Running `sh test-job.sh` or `bash test-job.sh` runs it **on slurm-master, outside Slurm** (no job ID, no limits).
> Right after submitting, `squeue` may briefly show `PD (InvalidAccount)` while accounting is not set up (before Part G). It should start within a few seconds.

Wait 30 seconds, then:

```bash
squeue                         # job is gone = finished
sacct 2>/dev/null || true      # accounting comes in Part G
ls ~/test-*.out
```

- The output file is written **on the compute node**, in the same path (`/home/ec2-user/test-<jobid>.out`). Without a shared file system (NFS) it is not on slurm-master. Read it **from the workstation** (it has SSH access to the nodes; slurm-master does not):

```bash
for n in slurm-node-1 slurm-node-2 slurm-node-3; do echo "== $n"; ssh $n 'cat ~/test-*.out 2>/dev/null'; done
```

> Production note: real clusters share `/home` (NFS or similar) on all nodes, so output files appear everywhere. That is a later step.

### F3. Check that limits work

- **Goal:** prove cgroups stop a job that uses more memory than it asked for.
- **Run on:** slurm-master

```bash
srun -N1 --mem=50M -t 2 python3 -c 'x = bytearray(200*1024*1024); print("should not get here")'
echo "exit code: $?"
```

- **Expected:** the job is killed: `error: Detected 1 oom_kill event` (or `Out Of Memory`), and a non-zero exit code. `should not get here` must **not** be printed.

**See the limits a job really gets** (memory in bytes; `52428800` = 50 MB; swap must be `0`):

```bash
srun -N1 --mem=50M -t 2 bash -c 'cg=/sys/fs/cgroup/system.slice/slurmstepd.scope/job_$SLURM_JOB_ID
  echo "memory.max=$(cat $cg/memory.max)  memory.swap.max=$(cat $cg/memory.swap.max)"'
```

- If `should not get here` **is** printed and `memory.swap.max` is not `0`: the job escaped into swap. Check that `cgroup.conf` has `ConstrainSwapSpace=yes` and `AllowedSwapSpace=0` (E4b), copy it (E5), and restart slurmd.

# PART G: Accounting with MariaDB and slurmdbd

**What happens here:** every job is recorded in a database: who ran it, which account, how long, how much CPU and memory. It also lets you control **who may run jobs** (accounts, users, limits).

```
slurmctld ──► slurmdbd (port 6819) ──► MariaDB (localhost:3306, database slurm_acct_db)
   all on slurm-master
```

**Doc (23.11.11):**
- Accounting: https://slurm.schedmd.com/archive/slurm-23.11.11/accounting.html
- slurmdbd.conf: https://slurm.schedmd.com/archive/slurm-23.11.11/slurmdbd.conf.html
- sacctmgr: https://slurm.schedmd.com/archive/slurm-23.11.11/sacctmgr.html

**t3.micro note:** slurm-master has only 717 MB RAM, so MariaDB is tuned small (G1). This is fine for a test. For production, give the database server more RAM (the Accounting doc suggests a much bigger `innodb_buffer_pool_size`) or a separate DB server.

**Most of Part G runs inside slurm-master.** Log in first:

```bash
ssh slurm-master
```

### G1. Install and tune MariaDB

- **Goal:** database server, reachable only from slurm-master itself.
- **Run on:** slurm-master
- **Doc:** Accounting → *MySQL Configuration*: set `innodb_buffer_pool_size`, `innodb_log_file_size`, `innodb_lock_wait_timeout`.

```bash
sudo dnf install -y mariadb-server

sudo tee /etc/my.cnf.d/slurm.cnf >/dev/null <<'EOF'
# Settings for Slurm accounting (Accounting doc -> MySQL Configuration)
# Sized for a small test server (t3.micro). Increase buffer_pool on bigger servers.
[mysqld]
bind-address=127.0.0.1
innodb_buffer_pool_size=128M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
max_connections=50
performance_schema=OFF
EOF

sudo systemctl enable --now mariadb
systemctl is-active mariadb
sudo mysql -e "SELECT VERSION(); SHOW VARIABLES WHERE Variable_name IN ('innodb_buffer_pool_size','innodb_lock_wait_timeout','bind_address');"
```

- **Expected:** `active`, a MariaDB version (10.5.x), buffer pool `134217728` (= 128 MB), lock wait `900`, bind `127.0.0.1`.
- `bind-address=127.0.0.1` = the database is **not** reachable from the network, only from slurm-master.

### G2. Secure MariaDB

- **Goal:** remove the default anonymous users and test database (same as `mysql_secure_installation`, without the questions).
- **Run on:** slurm-master
- On RHEL, MariaDB `root` can only log in through `sudo` on this server (unix socket), not with a password over the network.

```bash
sudo mysql <<'EOF'
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'slurm-master';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SELECT User, Host FROM mysql.user;
EOF
```

- **Expected:** only system users like `root`, `mysql`, `mariadb.sys` with host `localhost`. No empty user names.

### G3. Install slurmdbd

- **Run on:** slurm-master (package from our local repo, Part D)

```bash
sudo dnf install -y slurm-slurmdbd
rpm -q slurm-slurmdbd
```

- **Expected:** `slurm-slurmdbd-23.11.11-1.el9.x86_64`

### G4. Create the database, user and slurmdbd.conf

- **Goal:** a database `slurm_acct_db`, a DB user `slurm` with a random password, and `slurmdbd.conf` containing that password.
- **Run on:** slurm-master, **the whole block in one paste** (the password is kept in a shell variable and never shown on screen)
- **Doc:** Accounting → *MySQL Configuration* (create user + grant); slurmdbd.conf man page: *"this file should be only on the computer where SlurmDBD executes and should only be readable by the user which executes SlurmDBD"*.

```bash
DBPASS=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24)

sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS slurm_acct_db;
CREATE USER IF NOT EXISTS 'slurm'@'localhost' IDENTIFIED BY '${DBPASS}';
ALTER USER 'slurm'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo tee /etc/slurm/slurmdbd.conf >/dev/null <<EOF
# =====================================================================
# slurmdbd.conf - Slurm 23.11.11 (ONLY on slurm-master, owner slurm, mode 600)
# Docs: https://slurm.schedmd.com/archive/slurm-23.11.11/slurmdbd.conf.html
# =====================================================================
AuthType=auth/munge
DbdHost=slurm-master
DbdPort=6819
SlurmUser=slurm

LogFile=/var/log/slurm/slurmdbd.log
DebugLevel=info

StorageType=accounting_storage/mysql
StorageHost=localhost
StoragePort=3306
StorageLoc=slurm_acct_db
StorageUser=slurm
StoragePass=${DBPASS}

# Delete old records automatically (keeps the database small)
PurgeEventAfter=12month
PurgeJobAfter=12month
PurgeResvAfter=2month
PurgeStepAfter=2month
PurgeSuspendAfter=1month
PurgeTXNAfter=12month
PurgeUsageAfter=24month
EOF

sudo chown slurm:slurm /etc/slurm/slurmdbd.conf
sudo chmod 600 /etc/slurm/slurmdbd.conf
sudo restorecon /etc/slurm/slurmdbd.conf
unset DBPASS

sudo ls -l /etc/slurm/slurmdbd.conf
sudo grep -c '^StoragePass=.\{24\}$' /etc/slurm/slurmdbd.conf
sudo mysql -e "SHOW GRANTS FOR 'slurm'@'localhost';"
```

- **Expected:** `-rw------- 1 slurm slurm ... /etc/slurm/slurmdbd.conf`, then `1` (password line is filled in), then `GRANT ALL PRIVILEGES ON slurm_acct_db.* TO slurm@localhost`.
- **Never** copy `slurmdbd.conf` to other servers, Git or chat: it contains the DB password.
- Running G4 again is safe: it sets a **new** password in both MariaDB and slurmdbd.conf (then restart slurmdbd).

### G5. Start slurmdbd

- **Run on:** slurm-master
- The first start creates all tables. On t3.micro this can take a minute.

```bash
sudo systemctl enable --now slurmdbd
sleep 10
systemctl is-active slurmdbd
sudo tail -5 /var/log/slurm/slurmdbd.log
sudo mysql -e "SHOW TABLES FROM slurm_acct_db;" | head -5
```

- **Expected:** `active`, the log ends with `slurmdbd version 23.11.11 started`, and table names are listed.
- If not active: `sudo journalctl -u slurmdbd -n 30 --no-pager; sudo tail -30 /var/log/slurm/slurmdbd.log`

**Messages seen in the log on first start and what they mean:**

| Log message | Meaning | Action |
|---|---|---|
| `Unable to open pidfile '/var/run/slurmdbd.pid': Permission denied` | The 23.11 systemd unit runs slurmdbd as user `slurm`, which cannot write to `/var/run` | Fix below (G5b) |
| `Not running as root. Can't drop supplementary groups` | Info only: it already runs as `slurm` | None |
| `Database settings not recommended values: innodb_buffer_pool_size` | Our 128 MB buffer (G1) is below the recommendation | Accepted on t3.micro. On a bigger server raise `innodb_buffer_pool_size` in `/etc/my.cnf.d/slurm.cnf` and restart mariadb |

**G5b. Give slurmdbd its own PID folder** (systemd creates `/run/slurmdbd`, owned by `slurm`, at every start):

```bash
sudo mkdir -p /etc/systemd/system/slurmdbd.service.d
printf "[Service]\nRuntimeDirectory=slurmdbd\nRuntimeDirectoryMode=0755\n" |
  sudo tee /etc/systemd/system/slurmdbd.service.d/override.conf >/dev/null
sudo grep -q '^PidFile=' /etc/slurm/slurmdbd.conf ||
  echo "PidFile=/run/slurmdbd/slurmdbd.pid" | sudo tee -a /etc/slurm/slurmdbd.conf >/dev/null

sudo systemctl daemon-reload
sudo systemctl restart slurmdbd
sleep 5
systemctl is-active slurmdbd
ls -l /run/slurmdbd/
sudo tail -4 /var/log/slurm/slurmdbd.log
```

- **Expected:** `active`, `slurmdbd.pid` owned by `slurm` in `/run/slurmdbd/`, and **no** pidfile error in the newest log lines.

### G6. Switch slurm.conf to accounting

- **Goal:** tell slurmctld to send job records to slurmdbd, and to **only accept jobs from known users/accounts**.
- **Run on:** **workstation** (edit the master copy, then copy to all VMs with E5)
- **Doc:** Accounting → *Slurm Configuration*; slurm.conf man page → `AccountingStorageEnforce`.

```bash
cd ~/slurm-config
cp slurm.conf slurm.conf.before-accounting

sed -i 's|^AccountingStorageType=accounting_storage/none$|AccountingStorageType=accounting_storage/slurmdbd\nAccountingStorageHost=slurm-master\nAccountingStoragePort=6819\nAccountingStorageEnforce=associations,limits,qos\nJobAcctGatherFrequency=30|' slurm.conf
sed -i 's|^# ---- Accounting: none for now; Part G switches this to slurmdbd ----$|# ---- Accounting: slurmdbd on slurm-master (Part G) ----|' slurm.conf
grep -q '^SlurmctldPidFile=' slurm.conf ||
  sed -i '/^SlurmdDebug=info$/a SlurmctldPidFile=/run/slurmctld/slurmctld.pid' slurm.conf

diff slurm.conf.before-accounting slurm.conf
```

- **Expected diff:**
  ```
  > SlurmctldPidFile=/run/slurmctld/slurmctld.pid
  ...
  < # ---- Accounting: none for now; Part G switches this to slurmdbd ----
  < AccountingStorageType=accounting_storage/none
  ---
  > # ---- Accounting: slurmdbd on slurm-master (Part G) ----
  > AccountingStorageType=accounting_storage/slurmdbd
  > AccountingStorageHost=slurm-master
  > AccountingStoragePort=6819
  > AccountingStorageEnforce=associations,limits,qos
  > JobAcctGatherFrequency=30
  ```

| Line | Meaning |
|---|---|
| `AccountingStorageType=accounting_storage/slurmdbd` | Send job records to slurmdbd |
| `AccountingStorageHost` / `Port` | Where slurmdbd runs |
| `AccountingStorageEnforce=associations,limits,qos` | A user can only run jobs if they are registered in an account (G7). Limits set with `sacctmgr` are enforced |
| `JobAcctGatherFrequency=30` | Measure job CPU/memory every 30 seconds (shown in `sacct`) |
| `SlurmctldPidFile=/run/slurmctld/slurmctld.pid` | Like G5b: the 23.11 unit runs slurmctld as user `slurm` (`systemctl show -p User slurmctld`), so its PID file goes in a folder that `slurm` owns |

**PID folder for slurmctld** (same idea as G5b; takes effect at the restart in G8):

```bash
ssh slurm-master 'sudo mkdir -p /etc/systemd/system/slurmctld.service.d &&
  printf "[Service]\nRuntimeDirectory=slurmctld\nRuntimeDirectoryMode=0755\n" |
    sudo tee /etc/systemd/system/slurmctld.service.d/override.conf >/dev/null &&
  sudo systemctl daemon-reload && echo "override OK"'
```

Now copy `slurm.conf` to all VMs: **run E5** (same loop as before). All 4 VMs must show the same new checksum.

### G7. Register cluster, account and users

- **Goal:** create the cluster, a default account, and add the users who may run jobs. **Do this before G8**, or jobs will be rejected.
- **Run on:** slurm-master
- **Doc:** Accounting → *Database Configuration*; sacctmgr man page. `-i` = do it without asking "y/N".

```bash
sudo sacctmgr -i add cluster slurmdev
sudo sacctmgr -i add account general Description="General users" Organization=dev
sudo sacctmgr -i add user ec2-user DefaultAccount=general
sacctmgr show association format=Cluster,Account,User,Partition,QOS
```

- **Expected:** the last command shows rows for cluster `slurmdev`: account `root`, account `general`, and user `ec2-user` in `general`.
- `add cluster` may say the cluster already exists. That is fine.
- **Adding a new user later:** the Linux user must exist on all VMs with the same UID, then: `sudo sacctmgr -i add user <name> DefaultAccount=general`

### G8. Restart Slurm to use accounting

- **Goal:** slurmctld connects to slurmdbd; nodes read the new config.
- **Run on:** workstation
- Changing `AccountingStorageType` needs a **restart** of slurmctld (a reconfigure is not enough). Running jobs are not lost.

```bash
ssh slurm-master 'sudo systemctl restart slurmctld; sleep 5; systemctl is-active slurmctld; scontrol ping'
for n in slurm-node-1 slurm-node-2 slurm-node-3; do
  echo "== $n  $(ssh $n 'sudo systemctl restart slurmd; sleep 2; systemctl is-active slurmd')"
done
ssh slurm-master 'sinfo; sacctmgr show cluster format=Cluster,ControlHost,ControlPort,RPC; ls -l /run/slurmctld/'
```

- **Expected:** `active`, `Slurmctld(primary) at slurm-master is UP`, nodes `idle`, cluster `slurmdev` with ControlHost `172.21.10.116` and port `6817` (means slurmctld registered with slurmdbd).
- `/run/slurmctld/` stays **empty**: this is normal. The 23.11 unit starts slurmctld with `--systemd` (`Type=notify`), and in this mode systemd tracks the process itself, so no PID file is written (that is also why slurmctld never logged a pidfile error, unlike slurmdbd). The `SlurmctldPidFile` setting is kept so the path is valid if the start mode ever changes.

### G9. Test accounting

- **Run on:** slurm-master as `ec2-user`

```bash
sbatch ~/test-job.sh
srun -N3 hostname
sleep 40
sacct --format=JobID,JobName,User,Account,State,Elapsed,NodeList,MaxRSS
```

- **Expected:** the jobs listed with `Account=general`, `State=COMPLETED`, the node names, and `MaxRSS` filled in for the steps.

**Check that enforcement works** (a job with a wrong account must be refused):

```bash
srun --account=doesnotexist -N1 hostname
```

- **Expected:** `error: ... Invalid account or account/partition combination specified`.

### G10. Database backup

- **Goal:** a nightly copy of the accounting database (production must-have).
- **Run on:** slurm-master
- `--single-transaction` makes a consistent copy without stopping slurmdbd. Keeps the last 7 days.

```bash
sudo install -d -o root -g root -m 700 /var/backup/slurmdb

sudo tee /etc/cron.d/slurm-db-backup >/dev/null <<'EOF'
# Nightly Slurm accounting DB backup at 02:30 UTC, keep 7 days
30 2 * * * root mysqldump --single-transaction slurm_acct_db | gzip > /var/backup/slurmdb/slurm_acct_db-$(date +\%F).sql.gz && find /var/backup/slurmdb -name '*.sql.gz' -mtime +7 -delete
EOF

# Run once now to test:
sudo bash -c 'mysqldump --single-transaction slurm_acct_db | gzip > /var/backup/slurmdb/slurm_acct_db-$(date +%F).sql.gz'
sudo ls -lh /var/backup/slurmdb/
```

- **Expected:** one `.sql.gz` file, a few KB or more.
- Production note: also copy these backups off the server (for example to S3). A backup that only lives on the same disk is lost with the server.

---

# NEXT: Open items before real production

Parts A–G are done and tested: Slurm 23.11.11 with MUNGE, cgroup v2 limits (CPU, RAM, no swap), backfill scheduling, accounting with enforcement, log rotation and DB backup.

These items are **not** done yet. Each would be its own part, in this suggested order:

| # | Item | Why it matters |
|---|---|---|
| 1 | **Shared `/home`** (NFS or Amazon EFS) on all VMs | Job output files currently stay on the compute node that ran the job (seen in F2) |
| 2 | **Login node** on the workstation (`slurm` + `slurm-perlapi` packages, `munge` with the same key, `slurm.conf`, `munge`/`slurm` users with UID/GID 2001/2002) | Users submit jobs from a login node, not from the controller |
| 3 | **Central user management** (LDAP / FreeIPA / AD) | Every job user must exist with the same UID on all VMs. Today only `ec2-user` does |
| 4 | **`pam_slurm_adopt`** on compute nodes | Users can SSH to a node only while they have a job there |
| 5 | **Right-size the servers** (slurm-master ≥ t3.small/medium, raise `innodb_buffer_pool_size`; remove the swap workaround) | t3.micro is for testing only |
| 6 | **Off-server backups** (DB dumps + `/var/spool/slurmctld` + `/etc/slurm` + MUNGE key in a secret store) | Survive the loss of slurm-master |
| 7 | **Monitoring** (node state, daemon health, disk) | Find problems before users do |
| 8 | **Upgrade plan** away from 23.11 (Upgrade Guide: slurmdbd first, then slurmctld, then slurmd) | 23.11 gets no more security fixes |
| 9 | **Ansible** playbook built from this runbook | Repeatable builds; no manual copy-paste |
