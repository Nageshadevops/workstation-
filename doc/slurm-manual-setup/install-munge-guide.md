# MUNGE Installation and Configuration – AWS Slurm Cluster

## 1. Objective

Install and configure MUNGE authentication on the Slurm controller and all three compute nodes.

All four servers must use:
- The same MUNGE version.
- The same shared MUNGE authentication key.
- Correct file ownership and permissions.
- A running and enabled MUNGE service.

MUNGE is used by Slurm for authentication between cluster nodes.

## 2. Infrastructure Details

| Server | Private IP | Operating System | Role |
|---|---|---|---|
| Workstation | 172.22.7.185 | RHEL 9.8 | Administration and RPM build |
| Master | 172.21.10.169 | RHEL 9.6 | Slurm controller |
| Node 1 | 172.21.10.106 | RHEL 9 | Compute node |
| Node 2 | 172.21.10.241 | RHEL 9 | Compute node |
| Node 3 | 172.21.10.218 | RHEL 9 | Compute node |

### SSH access

Run these commands from the workstation.

```bash
# Master
ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.169

# Node 1
ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.106

# Node 2
ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.241

# Node 3
ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.218
```

## 3. MUNGE Version

Version: **0.5.18**

Official resources:

- Source code: https://github.com/dun/munge
- Releases: https://github.com/dun/munge/releases
- Installation guide: https://github.com/dun/munge/wiki/Installation-Guide

## 4. Build MUNGE RPM Packages

RPM packages were built on the workstation instead of installing MUNGE separately through DNF on every server.

### Step 1: Install build dependencies

Run on the workstation.

```bash
sudo dnf install -y rpm-build gcc dnf-plugins-core
```

### Step 2: Download MUNGE source

```bash
wget https://github.com/dun/munge/releases/download/munge-0.5.18/munge-0.5.18.tar.xz
```

### Step 3: Prepare source RPM

```bash
rpmbuild -ts munge-0.5.18.tar.xz
```

### Step 4: Install build dependencies

```bash
sudo dnf builddep ~/rpmbuild/SRPMS/munge-0.5.18-1.el9.src.rpm
```

### Step 5: Build binary RPM packages

```bash
rpmbuild -tb munge-0.5.18.tar.xz
```

### Step 6: Verify generated RPM packages

Packages are available in:

```text
~/rpmbuild/RPMS/x86_64/
```

Required packages:

```text
munge-0.5.18-1.el9.x86_64.rpm
munge-libs-0.5.18-1.el9.x86_64.rpm
```

Verify versions:

```bash
rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' \
~/rpmbuild/RPMS/x86_64/munge-0.5.18-1.el9.x86_64.rpm \
~/rpmbuild/RPMS/x86_64/munge-libs-0.5.18-1.el9.x86_64.rpm
```

## 5. Copy RPM Packages to Servers

Run from the workstation.

Example for Master:

```bash
scp -i ~/.ssh/slurm-dev-key \
~/rpmbuild/RPMS/x86_64/munge-0.5.18-1.el9.x86_64.rpm \
~/rpmbuild/RPMS/x86_64/munge-libs-0.5.18-1.el9.x86_64.rpm \
ec2-user@172.21.10.169:/home/ec2-user/
```

Repeat for Node 1, Node 2 and Node 3 by changing the destination IP.

## 6. Install MUNGE on Master

Connect to Master.

### Step 1: Install RPM packages

```bash
sudo rpm -Uvh ~/munge-libs-0.5.18-1.el9.x86_64.rpm ~/munge-0.5.18-1.el9.x86_64.rpm
```

### Step 2: Generate the shared MUNGE key

Generate the key only once, on Master.

```bash
sudo -u munge /usr/sbin/mungekey -v
```

The key is generated at:

```text
/etc/munge/munge.key
```

### Step 3: Set up a temporary copy for distribution

```bash
sudo cp /etc/munge/munge.key /home/ec2-user/munge.key
sudo chown ec2-user:ec2-user /home/ec2-user/munge.key
chmod 600 /home/ec2-user/munge.key
```

### Step 4: Start and enable MUNGE

```bash
sudo systemctl enable --now munge
```

### Step 5: Verify service

```bash
sudo systemctl status munge --no-pager
```

Expected:

```text
Active: active (running)
```

### Step 6: Test local authentication

```bash
munge -n | unmunge
```

Expected:

```text
STATUS: Success (0)
```

## 7. Distribute the Shared MUNGE Key

The same key generated on Master must be installed on every compute node.

First, copy the key from Master to the workstation.

Run on the workstation:

```bash
scp -i ~/.ssh/slurm-dev-key \
ec2-user@172.21.10.169:/home/ec2-user/munge.key \
~/munge.key
```

Then copy the key from the workstation to all compute nodes:

```bash
scp -i ~/.ssh/slurm-dev-key ~/munge.key ec2-user@172.21.10.106:/home/ec2-user/

scp -i ~/.ssh/slurm-dev-key ~/munge.key ec2-user@172.21.10.241:/home/ec2-user/

scp -i ~/.ssh/slurm-dev-key ~/munge.key ec2-user@172.21.10.218:/home/ec2-user/
```

## 8. Install MUNGE on Compute Nodes

Perform the following steps separately on Node 1, Node 2 and Node 3.

### Step 1: Install RPM packages

```bash
sudo rpm -Uvh ~/munge-libs-0.5.18-1.el9.x86_64.rpm ~/munge-0.5.18-1.el9.x86_64.rpm
```

### Step 2: Install the shared MUNGE key

```bash
sudo install -o munge -g munge -m 0400 ~/munge.key /etc/munge/munge.key
```

Explanation:

| Option | Purpose |
|---|---|
| `sudo` | Execute with administrator privileges |
| `install` | Copy the file and set permissions |
| `-o munge` | Set owner to munge |
| `-g munge` | Set group to munge |
| `-m 0400` | Owner read-only permission |
| Source | `~/munge.key` |
| Destination | `/etc/munge/munge.key` |

### Step 3: Start and enable MUNGE

```bash
sudo systemctl enable --now munge
```

### Step 4: Verify service

```bash
sudo systemctl status munge --no-pager
```

Expected:

```text
Active: active (running)
```

### Step 5: Test local authentication

```bash
munge -n | unmunge
```

Expected:

```text
STATUS: Success (0)
```

## 9. Local Authentication Verification

The following command was executed on all four servers:

```bash
munge -n | unmunge
```

Results:

| Server | IP | Result |
|---|---|---|
| Master | 172.21.10.169 | PASS |
| Node 1 | 172.21.10.106 | PASS |
| Node 2 | 172.21.10.241 | PASS |
| Node 3 | 172.21.10.218 | PASS |

All four servers successfully generated and decoded their own MUNGE credentials.

## 10. Cross-Node Authentication Verification

Local authentication alone does not confirm that all servers share the same key.

Therefore, cross-node authentication was tested from the workstation.

### Master to Node 1

```bash
ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.169 'munge -n' | ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.106 'unmunge'
```

Result:

```text
STATUS: Success (0)
```

### Master to Node 2

```bash
ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.169 'munge -n' | ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.241 'unmunge'
```

Result:

```text
STATUS: Success (0)
```

### Master to Node 3

```bash
ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.169 'munge -n' | ssh -i ~/.ssh/slurm-dev-key ec2-user@172.21.10.218 'unmunge'
```

Result:

```text
STATUS: Success (0)
```

### How the cross-node test works

1. Master executes `munge -n` and generates an authentication credential.
2. The Linux pipe (`|`) passes the credential to the next command.
3. SSH sends the credential to the compute node.
4. The compute node executes `unmunge`.
5. The compute node decodes the credential using its own MUNGE key.

If the shared key is correct, the result is:

```text
STATUS: Success (0)
```

All three cross-node tests passed.

## 11. Security Cleanup

After successful verification, temporary copies of the shared key were removed from the user home directories.

The permanent key must remain at:

```text
/etc/munge/munge.key
```

Temporary copies removed:

```text
/home/ec2-user/munge.key
```

The temporary workstation copy was also removed.

The key file under `/etc/munge/` must not be deleted.

## 12. Final MUNGE Configuration Status

| Task | Status |
|---|---|
| Build MUNGE RPMs | Completed |
| Install MUNGE on Master | Completed |
| Generate shared MUNGE key | Completed |
| Install MUNGE on Node 1 | Completed |
| Install MUNGE on Node 2 | Completed |
| Install MUNGE on Node 3 | Completed |
| Distribute shared key | Completed |
| Enable MUNGE services | Completed |
| Master local authentication | Passed |
| Node 1 local authentication | Passed |
| Node 2 local authentication | Passed |
| Node 3 local authentication | Passed |
| Master to Node 1 authentication | Passed |
| Master to Node 2 authentication | Passed |
| Master to Node 3 authentication | Passed |
| Temporary key cleanup | Completed |

**Overall status: MUNGE installation and authentication verification completed successfully.**

## 13. Next Phase – Slurm Installation

MUNGE is a prerequisite for Slurm authentication.

Next tasks:

1. Select and download the Slurm version.
2. Decide the installation method (RPM packages built from source or another controlled package method).
3. Install Slurm components on the Master and compute nodes.
4. Configure `slurm.conf`.
5. Configure Slurm controller and compute-node services.
6. Start the Slurm cluster.
7. Verify nodes using `sinfo` and `scontrol`.
8. Submit a test job using `sbatch` and verify execution.

**Note:** MUNGE is ready. Slurm installation and cluster configuration are the next phase.


Aws Autoscaling 