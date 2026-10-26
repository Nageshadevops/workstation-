# Stage 4: Workstation as Slurm login node (manual)

Users log in **only to the workstation** and submit jobs from there. They never log in to
slurm-master or the nodes. Slurm runs their jobs on the nodes **as that user**.

Everything here was done **by hand** on 2026-10-26, to understand each piece before automating
it. It is not in Terraform or Ansible yet (see [What is lost on make destroy](#what-is-lost-on-make-destroy)).

```
user laptop (WSL) ──ssh -X slurmtest1@40.192.85.194──► workstation (login node)
                                                         │ sinfo / srun / sbatch / sacct
                                                         ▼
                                                       slurm-master   (slurmctld 6817, slurmdbd 6819)
                                                         │
                                                         ▼
                                                       slurm-node-1..3 (slurmd 6818, run the jobs)
```

Not included (not needed for testing yet): shared storage (NFS/EFS), simulation software.
Without shared storage, an `sbatch` job's output file stays on the node that ran it;
`srun` output comes straight back to the user's terminal.

## Requirements for a login node

| # | Requirement | Why |
|---|---|---|
| 1 | Network: workstation → master 6817 + 6819, workstation → nodes 6818, nodes → workstation all TCP | Slurm commands talk to slurmctld, slurmdbd and slurmd; nodes connect back to `srun` |
| 2 | Slurm client on the workstation: munge with the **same key**, the same Slurm build, the same `slurm.conf`, cluster names in `/etc/hosts`, PATH | the commands need config and munge to prove who the user is |
| 3 | Every user exists on the workstation **and on the master and every node, with the same uid** | slurmctld must know the uid; the job runs as that uid on the node |
| 4 | Every user in accounting (`sacctmgr`) | job history per user/account |
| 5 | Users log in to the workstation directly (SSH key) | no shared admin account, no `su` |

Users used for the test (uids from the workstation, used everywhere):

| User | uid / gid |
|---|---|
| slurmtest1 | 1002 |
| slurmtest2 | 1003 |
| slurmtest3 | 1004 |

`siddug` is uid 1001 on the workstation (admin only, does not submit jobs).

---

## Part 1: Network (AWS console)

**1a. `slurm-dev-sg`** (EC2 → Security Groups → slurm-dev-sg → Edit inbound rules), source
`172.22.7.210/32` (workstation private IP) for all three:

| Type | Port | Description |
|---|---|---|
| Custom TCP | 6817 | slurmctld from workstation |
| Custom TCP | **6818** | slurmd from workstation (srun) |
| Custom TCP | 6819 | slurmdbd from workstation |

`slurm-dev-sg` is on all 4 Slurm servers, so the 6818 rule covers every node.

**1b. `workstation-sg`**: Custom → **All TCP** from `172.21.10.0/24` (Slurm private subnet),
description `srun callbacks from Slurm nodes`. Only reachable over the peering, not from the
internet.

**Check** (on the workstation, after part 2 step 6 for the names):

```bash
timeout 3 bash -c '</dev/tcp/slurm-master/6817' && echo "6817 open"
timeout 3 bash -c '</dev/tcp/slurm-master/6819' && echo "6819 open"
timeout 3 bash -c '</dev/tcp/slurm-node-1/6818' && echo "6818 open"
```

`/dev/tcp/<host>/<port>` is a bash feature that opens a TCP connection; nothing to install.

---

## Part 2: Slurm client on the workstation

Run as **siddug** (it has `~/.ssh/slurm-dev-key` for the Slurm servers); commands that need root
have `sudo`. MASTER_IP = slurm-master's private IP from `make output`.

| Step | Commands | Check |
|---|---|---|
| 1. munge + slurm users (same uids as the cluster, **before** installing munge) | `sudo groupadd -g 791 munge`<br>`sudo useradd -u 791 -g 791 -s /sbin/nologin -M munge`<br>`sudo groupadd -g 792 slurm`<br>`sudo useradd -u 792 -g 792 -s /sbin/nologin -M slurm` | `id munge; id slurm` |
| 2. packages | `sudo dnf config-manager --set-enabled codeready-builder-for-rhel-9-rhui-rpms`<br>`sudo dnf install -y munge munge-libs openssl pam-devel numactl hwloc lua readline rrdtool ncurses rdma-core json-c dbus-libs libbpf mariadb-connector-c bzip2` | |
| 3. munge key from the master | `ssh -i ~/.ssh/slurm-dev-key ec2-user@MASTER_IP "sudo cat /etc/munge/munge.key" \| sudo tee /etc/munge/munge.key > /dev/null`<br>`sudo chown munge:munge /etc/munge/munge.key`<br>`sudo chmod 400 /etc/munge/munge.key`<br>`sudo systemctl enable --now munge` | `sudo md5sum /etc/munge/munge.key` = same on the master;<br>`munge -n \| ssh -i ~/.ssh/slurm-dev-key ec2-user@MASTER_IP unmunge` → `STATUS: Success (0)` |
| 4. Slurm build (made by Ansible, already on the workstation) | `sudo tar xzf ~/workstation-/slurm/ansible/files/slurm-install-25.11.3.tgz -C /usr/local` | |
| 5. slurm.conf from the master | `sudo mkdir -p /etc/slurm`<br>`ssh -i ~/.ssh/slurm-dev-key ec2-user@MASTER_IP "cat /etc/slurm/slurm.conf" \| sudo tee /etc/slurm/slurm.conf > /dev/null` | `/usr/local/slurm/bin/sinfo -V` → `slurm 25.11.3` |
| 6. cluster names | `ssh -i ~/.ssh/slurm-dev-key ec2-user@MASTER_IP "grep slurm- /etc/hosts"`, add the 4 lines with `sudo vi /etc/hosts` | `ping -c1 slurm-master` |
| 7. PATH for everyone | `echo 'export PATH=/usr/local/slurm/bin:$PATH' \| sudo tee /etc/profile.d/slurm.sh`<br>`sudo chmod 644 /etc/profile.d/slurm.sh`, then log in again | `which sinfo` |
| 8. test | `sinfo`, `squeue` | `debug* up infinite 3 idle slurm-node-[1-3]` |

Only `/usr/local/slurm/bin` goes on the PATH: the daemons in `sbin` do not run on the workstation.

**Result (2026-10-26):** munge checksums equal (`a4b2c970...`), cross-server unmunge Success,
`sinfo` on the workstation shows 3 idle nodes.

---

## Part 3: Users with the same uid everywhere

On **slurm-master, slurm-node-1, slurm-node-2, slurm-node-3**, as root
(`make ssh HOST=<server>`, then `sudo -i`), type **one line at a time**:

```bash
getent passwd 1002 1003 1004          # must print nothing (uids free)
groupadd -g 1002 slurmtest1
useradd -u 1002 -g 1002 -m slurmtest1
groupadd -g 1003 slurmtest2
useradd -u 1003 -g 1003 -m slurmtest2
groupadd -g 1004 slurmtest3
useradd -u 1004 -g 1004 -m slurmtest3
id slurmtest1; id slurmtest2; id slurmtest3
```

- `-m` creates `/home/<user>` on the server: a job starts in the folder it was submitted from,
  so it must exist on the node.
- No password: these users never log in to the Slurm servers.
- **The master needs the users too**, not only the nodes (see lessons learned).

If a user already exists with a **wrong uid** (node-1 had slurmtest1-3 as 1001-1003 from an
earlier test), remove it first:

```bash
ps -u slurmtest1            # anything still running as the user?
pkill -u slurmtest1         # stop it, otherwise userdel refuses
userdel -r slurmtest1       # also removes the home folder
getent group slurmtest1     # still there? groupdel slurmtest1
```

---

## Part 4: Accounting

On slurm-master as root:

```bash
sacctmgr show account                         # is "default" there?
sacctmgr -i add account default Cluster=slurmcluster Description="default account"   # only if missing
sacctmgr -i add user slurmtest1 Account=default
sacctmgr -i add user slurmtest2 Account=default
sacctmgr -i add user slurmtest3 Account=default
sacctmgr show association format=cluster%15,account%10,user%12
```

Account `default` is normally created by the Ansible accounting play (step 3.7). If
`sacctmgr add user` says `Make sure the accounts requested here have been added`, it is missing.

---

## Part 5: Direct user login to the workstation (SSH key)

The workstation allows password login only for siddug (`/etc/ssh/sshd_config.d/10-hardening.conf`)
and SSH is open to the internet, so users get **SSH keys**, not passwords.

1. **User, on their own laptop (WSL):**
   ```bash
   ssh-keygen -t ed25519 -C "slurmtest1-laptop"
   cat ~/.ssh/id_ed25519.pub        # send this ONE line to the admin; the private key stays on the laptop
   ```
   Testing alone: `ssh-keygen -t ed25519 -f ~/.ssh/slurmtest1_key` on your own WSL.

2. **Admin, on the workstation as siddug:**
   ```bash
   sudo mkdir -p /home/slurmtest1/.ssh
   sudo vi /home/slurmtest1/.ssh/authorized_keys        # paste the line
   sudo chown -R slurmtest1:slurmtest1 /home/slurmtest1/.ssh
   sudo chmod 700 /home/slurmtest1/.ssh
   sudo chmod 600 /home/slurmtest1/.ssh/authorized_keys
   sudo restorecon -Rv /home/slurmtest1/.ssh            # SELinux label (workstation is enforcing)
   id slurmtest1                                        # must NOT include wheel (no sudo)
   ```

3. **User logs in:**
   ```bash
   ssh -X slurmtest1@40.192.85.194        # or: ssh -X -i ~/.ssh/slurmtest1_key ...
   ```

---

## Part 6: Test (as the user, on the workstation)

```bash
sinfo                                         # 3 idle nodes
srun whoami                                   # slurmtest1 (runs on a node as the user)
srun -N3 hostname                             # slurm-node-1, -2, -3
sbatch --wrap="hostname; whoami; sleep 60"    # Submitted batch job N
squeue                                        # USER slurmtest1, ST R
sacct -X --format=JobID,JobName,User,Account,State,NodeList
sbatch --wrap="sleep 300"; scancel <jobid>    # State CANCELLED
```

**Result (2026-10-26):** as root and as slurmtest1 from the workstation: `srun hostname`,
`srun -N3 hostname` and `srun whoami` → `slurmtest1` all work.

### GUI jobs (X11)

The window travels node → Slurm's X11 tunnel → workstation → `ssh -X` → laptop. Needs:

- the user connected from **WSL Ubuntu** (WSLg is the X server). **Windows CMD/PowerShell
  `ssh -X` does not work**: Windows has no X server.
- `xorg-x11-xauth` on the workstation (`echo $DISPLAY` after `ssh -X` shows `localhost:10.0`).
- **`srun --x11`**: without `--x11`, Slurm does not forward X11.

```bash
echo $DISPLAY          # localhost:10.0
srun --x11 xclock
```

**Testing with `su` instead of a direct login:** `sudo -i` / `su - slurmtest1` drop `DISPLAY` and
the X11 cookie (the "password" for the display). Pass them by hand:

```bash
# as siddug (logged in with ssh -X from WSL):
echo $DISPLAY                 # e.g. localhost:10.0
xauth list $DISPLAY           # one line: workstation/unix:10  MIT-MAGIC-COOKIE-1  <hex>
# then:
sudo -i
su - slurmtest1
export DISPLAY=localhost:10.0
xauth add <the whole line from xauth list>    # "file ... does not exist" = it creates it, fine
srun --x11 xclock
```

The display exists only while that `ssh -X` session is open; a new login can get a new number
(`localhost:11.0`) and a new cookie. With a direct `ssh -X slurmtest1@...` login none of this
is needed.

---

## Lessons learned

| Symptom | Cause | Fix |
|---|---|---|
| `sinfo -V`: `resolve_ctls_from_dns_srv ... Could not establish a configuration source` | no `/etc/slurm/slurm.conf` yet; Slurm then tries "configless" DNS SRV lookup | copy slurm.conf (part 2 step 5) |
| `sinfo: command not found` | PATH not loaded | `/etc/profile.d/slurm.sh`, log in again |
| `Identity file /root/.ssh/slurm-dev-key not accessible` + `Permission denied` | ran as root: `~` = `/root`; the key is in siddug's home | run as siddug |
| root: `Task launch ... failed on node: Communication connection failure` | **port 6818 workstation → nodes missing**: `srun` connects directly to slurmd on each node | slurm-dev-sg: TCP 6818 from 172.22.7.210/32 |
| user: `Nodes slurm-node-1 are still not ready` / `Something is wrong with the boot of the nodes`, root works | **user missing on slurm-master** (slurmctld cannot resolve the uid) | create the user on the master with the same uid |
| `groupadd: group 'slurmtest1' already exists` / `userdel` did not remove the user | a process still ran as the user (earlier login) | `pkill -u <user>`, `userdel -r`, `groupdel` |
| `sacctmgr add user`: `Nothing added ... Make sure the accounts ... have been added` | account `default` missing | `sacctmgr -i add account default Cluster=slurmcluster` |
| `srun xclock`: `Can't open display:` | no `DISPLAY`: CMD instead of WSL, or `su` dropped it, and no `--x11` | WSL + `ssh -X`, `srun --x11`, cookie for `su` |
| commands pasted together with `sudo -i` did not run | `sudo -i` starts a new shell; pasted lines are lost | type/paste one line at a time after the root prompt |

---

## What is lost on make destroy

| Survives (workstation, workstation-sg) | Lost (Slurm servers, slurm-dev-sg) → redo after `make apply` + `make ansible-slurm` |
|---|---|
| Part 1b: workstation-sg rule | Part 1a: the 3 slurm-dev-sg rules (6817, 6818, 6819) |
| Part 2 steps 1, 2, 4, 7: users, packages, Slurm build, PATH | Part 2 steps 3, 5, 6: **new** munge key, slurm.conf (new master IP), /etc/hosts lines (new IPs) |
| Part 5: user logins and keys on the workstation | Part 3: users on master and nodes |
| | Part 4: users in accounting |

## To automate later

- Terraform: slurm-dev-sg rules 6817/6818/6819 from the workstation; the workstation-sg rule.
- Ansible: a `[login]` group with the workstation (`ansible_connection=local`) getting munge key,
  Slurm build, slurm.conf, /etc/hosts, PATH; a user list with fixed uids and SSH keys, created
  on all servers and in accounting.
- Security before real users: SSH in workstation-sg limited to the office IP range, fail2ban,
  automatic security updates (open items from Workstation-Setup.docx).
