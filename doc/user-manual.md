# User Manual: Slurm Test Cluster on AWS

This manual explains, step by step, how to **start**, **use** and **stop** our Slurm test cluster.
You do not need to know AWS, Terraform, Ansible or Slurm before you begin: every command is
given, with what you should see. Read sections 1 and 2 once; after that, sections 4–6 are your
daily routine.

If something here does not match what you see, stop and ask before trying fixes of your own.

---

## Contents

1. [What is this?](#1-what-is-this)
2. [Words you will see](#2-words-you-will-see)
3. [Before you start (one time)](#3-before-you-start-one-time)
4. [Start the cluster](#4-start-the-cluster)
5. [Use the cluster (run jobs)](#5-use-the-cluster-run-jobs)
6. [Stop the cluster (save money)](#6-stop-the-cluster-save-money)
7. [When something goes wrong](#7-when-something-goes-wrong)
8. [Rules](#8-rules)
9. [Cheat sheet](#9-cheat-sheet)

---

## 1. What is this?

**Slurm** is the program that shares a group of computers (a *cluster*) between many users: you
ask for CPUs, Slurm finds free ones and runs your program there. Our company uses Slurm on its
own servers ("on-prem"). This project builds a **small copy of it in AWS** for testing and
learning.

The cluster has 4 servers:

| Server | Job |
|---|---|
| `slurm-master` | the boss: receives jobs, decides where they run, keeps job history |
| `slurm-node-1`, `slurm-node-2`, `slurm-node-3` | the workers: run the jobs |

You never log in to them directly from your laptop. You go through the **workstation**, a
small admin server in AWS:

```
Your laptop  ──ssh──►  workstation  ──ssh──►  slurm-master, slurm-node-1..3
(Windows+WSL)          (AWS, user siddug)      (AWS, private network only)
```

Everything is created by **one command** and deleted by **one command**. Because of that, we
delete the cluster when nobody uses it (it costs money per hour) and create it again the next day.

---

## 2. Words you will see

| Word | Simple meaning |
|---|---|
| **AWS** | Amazon's cloud: we rent servers and networks there |
| **Region** | where in the world the servers are; ours: **ap-south-2 (Hyderabad)** |
| **VPC** | a private network in AWS. Ours: `slurm-dev-vpc` (cluster) and `workstation-vpc` (workstation) |
| **EC2 instance** | a server (virtual machine) in AWS |
| **NAT gateway** | lets the cluster servers download software from the internet, while nobody on the internet can reach them |
| **Terraform** | a tool that creates AWS things (network, servers) from code files. Our code: `slurm/terraform/` |
| **Ansible** | a tool that logs in to servers and installs/configures software. Our code: `slurm/ansible/` |
| **make** | runs our short commands (`make plan`, `make apply`, ...) so you don't type long ones |
| **Terraform state** | Terraform's notebook of what it created. File on the workstation; **never delete it** |
| **munge** | how the Slurm servers prove to each other who they are (a shared secret key) |
| **job** | a program you ask Slurm to run |
| **partition** | a group of nodes jobs can go to. Ours: `debug` (all 3 nodes) |
| **node** | a worker server |

---

## 3. Before you start (one time)

You need, from your team lead:

- [ ] Windows 11 laptop with **WSL Ubuntu**
- [ ] A **login on the workstation** (user name + SSH key or password)
- [ ] Access to the GitHub repo **Nageshadevops/workstation-** and a **GitHub token**
- [ ] Permission to run the cluster (only **one person** at a time runs Terraform, see [Rules](#8-rules))

How to set up the laptop and the workstation is in **[00-setup.md](00-setup.md)**. Do that first,
with your team lead if it is your first time.

Check that you can log in to the workstation:

```bash
ssh siddug@40.192.85.194
```

You should see a prompt like:

```
[siddug@workstation ~]$
```

**Every command from section 4 on is typed on the workstation**, unless it says otherwise.

---

## 4. Start the cluster

Takes about **25 minutes** in total, most of it waiting.

### Step 1: Go to the project folder and get the latest code

```bash
cd ~/workstation-
git pull
cd slurm
```

`git pull` downloads the latest changes from GitHub. You should see `Already up to date.` or a
list of changed files. Your prompt now ends with `slurm]$`.

> **Always run `make` commands from `~/workstation-/slurm`.** Anywhere else, make says
> `No rule to make target`.

### Step 2: Prepare Terraform (only the first time on this workstation)

```bash
make init
```

Expected at the end:

```
Terraform has been successfully initialized!
```

If the folder was already initialized before, running it again is harmless.

### Step 3: See what will be created

```bash
make plan
```

Terraform compares the code with what exists in AWS and prints a list. At the end:

```
Plan: 26 to add, 0 to change, 0 to destroy.
```

- **26 to add** = the cluster does not exist yet, everything will be created. Normal.
- **0 to add, ... No changes** = the cluster already exists. Skip step 4.
- **anything "to destroy" or "to change"** that you did not expect: **stop and ask.**

The first time, `make plan` also creates your SSH key for the cluster (`~/.ssh/slurm-dev-key`).

### Step 4: Create it

```bash
make apply
```

Takes about 3 minutes (the NAT gateway is the slow part). Expected at the end:

```
Apply complete! Resources: 26 added, 0 changed, 0 destroyed.

Outputs:
instances = {
  "slurm-master" = { "id" = "i-...", "private_ip" = "172.21.10.x" }
  "slurm-node-1" = ...
```

The servers now exist but still need 1–2 minutes to boot. **Wait 2 minutes.**

### Step 5: Check that Ansible can reach the servers

```bash
make ping
```

You should see this **4 times** (once per server):

```
slurm-master | SUCCESS => {
    ...
    "ping": "pong"
}
```

`UNREACHABLE` = the servers are still booting. Wait one more minute and try again.

### Step 6: Install and configure Slurm

```bash
make ansible-slurm
```

Takes about **20 minutes**. Lots of text scrolls by. That is normal:

- `ok` (green) = already correct, nothing to do
- `changed` (yellow) = Ansible changed something
- `skipping` (blue) = not needed on this server
- `ASYNC POLL ... finished=False` for ~10 minutes = Slurm is being compiled; just wait
- `failed` / `fatal` (red) = a problem, see [section 7](#7-when-something-goes-wrong)

At the very end you should see:

```
TASK [Print sinfo]
ok: [slurm-master] => {
    "sinfo.stdout_lines": [
        "PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST",
        "debug*       up   infinite      3   idle slurm-node-[1-3]"
    ]
}

PLAY RECAP
slurm-master   : ok=..  changed=..  unreachable=0  failed=0 ...
slurm-node-1   : ok=..  changed=..  unreachable=0  failed=0 ...
slurm-node-2   : ok=..  changed=..  unreachable=0  failed=0 ...
slurm-node-3   : ok=..  changed=..  unreachable=0  failed=0 ...
```

**`failed=0` and `unreachable=0` on all 4 lines = the cluster is ready.**

Running `make ansible-slurm` again is always safe: it only fixes what is wrong. A second run
should end with `changed=0`.

---

## 5. Use the cluster (run jobs)

### Log in to the master

```bash
make ssh
```

Your prompt changes to:

```
[ec2-user@slurm-master ~]$
```

You are now on the cluster. (Ignore the "Register this system with Red Hat Insights" text.)
To go back to the workstation: `exit`.

To log in to a node instead: `make ssh HOST=slurm-node-1`.

### Look at the cluster

```bash
sinfo
```

```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      3   idle slurm-node-[1-3]
```

| Column | Meaning |
|---|---|
| `debug*` | partition name; `*` = the default one |
| `idle` | nodes are free. Others: `alloc`/`mix` (busy), `down`/`drain` (problem) |

### Run a program right now: `srun`

```bash
srun hostname
```

```
slurm-node-1
```

Slurm picked a free node, ran `hostname` there, and showed you the output. More examples:

```bash
srun -N3 hostname          # on 3 nodes (-N = number of nodes)
srun -N2 -n4 hostname      # 4 copies (-n = tasks) spread over 2 nodes
srun --pty bash            # an interactive shell on a node; type exit to leave
```

`srun` waits until the program finishes. Good for short tests.

### Run a program in the background: `sbatch`

For longer work, write a small script and submit it. Create `myjob.sh`:

```bash
cat > myjob.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=myfirstjob
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=myjob-%j.out

echo "Running on $(hostname)"
sleep 60
echo "Done"
EOF
```

Lines starting with `#SBATCH` are settings for Slurm; `%j` becomes the job number.

Submit it:

```bash
sbatch myjob.sh
```

```
Submitted batch job 7
```

You get your prompt back immediately; the job runs on a node.

### Watch, cancel, and check jobs

```bash
squeue                     # running (R) and waiting (PD) jobs
scancel 7                  # cancel job 7
cat myjob-7.out            # the job's output, after it ran
sacct                      # history of your jobs (from the database)
sacct -X --format=JobID,JobName,Account,State,Elapsed
scontrol show job 7        # all details of one job
```

`squeue` example:

```
JOBID PARTITION     NAME     USER ST  TIME  NODES NODELIST(REASON)
    7     debug myfirstj ec2-user  R  0:12      1 slurm-node-1
```

`ST`: `R` = running, `PD` = pending (waiting for free nodes), `CG` = finishing.

`sacct` states: `COMPLETED` (ok), `FAILED` (program returned an error), `CANCELLED`, `TIMEOUT`.

### A GUI program (optional)

You can open a window from a job on your laptop screen. Every hop needs `-X`:

```bash
# on the laptop (WSL):
ssh -X siddug@40.192.85.194
# on the workstation:
cd ~/workstation-/slurm
make ssh SSH_ARGS=-X
# on slurm-master:
echo $DISPLAY              # must print something like localhost:10.0
srun --x11 xclock          # a clock appears on your laptop; close it to end the job
```

If `echo $DISPLAY` prints nothing, one of the `ssh` steps was without `-X`.
Installed GUI programs: `xclock`, `xterm`.

### Leave the cluster

```bash
exit                       # back to the workstation
```

---

## 6. Stop the cluster (save money)

The cluster costs roughly **$0.20–0.30 per hour** (servers + NAT gateway), even when no job runs.
**When you finish for the day, delete it.** You can create it again tomorrow with section 4.

On the workstation:

```bash
cd ~/workstation-/slurm
make destroy
```

Terraform lists everything it will delete and asks:

```
Plan: 0 to add, 0 to change, 26 to destroy.

Do you really want to destroy all resources?
  Enter a value:
```

Check that the number is about 26 and every name starts with `aws_...` from our code, then type:

```
yes
```

Expected at the end (2–3 minutes):

```
Destroy complete! Resources: 26 destroyed.
```

What is deleted / what stays:

| Deleted | Stays |
|---|---|
| the 4 Slurm servers and all data on them (your files, job history) | the workstation and its files |
| the cluster network, NAT gateway, key pair in AWS | the code in git, your `~/.ssh/slurm-dev-key` |

**Copy anything you want to keep off the cluster before `make destroy`.** For example, from the
workstation: `scp -i ~/.ssh/slurm-dev-key ec2-user@<master-ip>:myjob-7.out .`
(`make output` shows the IPs).

---

## 7. When something goes wrong

First: **read the last red lines**. They usually say what is wrong. Then find it below.

| You see | What it means | What to do |
|---|---|---|
| `make: *** No rule to make target 'plan'` | wrong folder | `cd ~/workstation-/slurm` |
| `make plan` shows something **to destroy** or **to change** you did not expect | someone changed AWS or the code | **stop, ask** |
| `Error: ... UnauthorizedOperation` / `ExpiredToken` / `InvalidClientTokenId` | AWS access problem | `aws sts get-caller-identity`; if it fails, ask for new AWS keys |
| `make ping`: `UNREACHABLE` | servers still booting | wait 1–2 minutes, try again |
| `make ping`: `UNREACHABLE` after 5 minutes | network problem | `make ssh` — if it also hangs, ask |
| `Permission denied (publickey)` | wrong key / user | use `make ssh`, not plain `ssh` |
| `make ansible-slurm` stops with `fatal` | a task failed | run `make ansible-slurm` once more (it continues where it is safe); if the same task fails again, copy the red lines and ask |
| `sinfo`: `command not found` | PATH not loaded | `exit` and `make ssh` again |
| `sinfo`: nodes `down` or `drain` | a node has a problem | `scontrol show node slurm-node-1` → read `Reason=`; then ask, or `sudo /usr/local/slurm/bin/scontrol update NodeName=slurm-node-1 State=RESUME` |
| job `FAILED`, `execve(): <program>: No such file or directory` | that program is not installed on the nodes | use an installed program, or ask |
| `srun: error: No DISPLAY variable set` | no `-X` in one ssh step | see "A GUI program" in section 5 |
| `make destroy` asks for `yes` and you are unsure | — | type `no` (or Ctrl+C) and ask |

When you ask for help, send:

1. the command you ran,
2. the **last 20–30 lines** of output,
3. the output of `make output` (shows what exists).

More details for each part: [01-vpc.md](01-vpc.md), [02-vms.md](02-vms.md), [03-slurm.md](03-slurm.md).

---

## 8. Rules

**Do:**

- Run `git pull` before `make plan`.
- Read the `make plan` summary **before** `make apply`.
- `make destroy` at the end of the day (unless your lead says to keep it running).
- Change things **in the code** (git), never by hand in the AWS console or on the servers. Ansible
  overwrites hand changes on the servers; hand changes in AWS confuse Terraform.
- Ask when an output looks different from this manual.

**Don't:**

- **Don't run Terraform at the same time as another person**, and don't run it from another
  copy of the repo. Terraform's state file lives in `~/workstation-/slurm/terraform/` on the
  workstation; a second copy would try to build a second cluster.
- **Don't delete or edit** `slurm/terraform/terraform.tfstate`.
- **Don't delete or change** anything in the AWS console that Terraform created (names starting
  with `slurm-dev-`), and never touch `workstation-vpc` or the workstation instance.
- **Don't put secrets in git**: no `.pem` keys, AWS keys, passwords or tokens.
- Don't store important files only on the cluster: `make destroy` deletes them.

---

## 9. Cheat sheet

**On the workstation** (in `~/workstation-/slurm`):

| Command | What |
|---|---|
| `git pull` | get the latest code |
| `make init` | first time only: prepare Terraform |
| `make plan` | show what would be created/changed |
| `make apply` | create/change it (after `make plan`) |
| `make ping` | can Ansible reach all servers? |
| `make ansible-slurm` | install/fix Slurm on all servers |
| `make ssh` | log in to slurm-master |
| `make ssh HOST=slurm-node-2` | log in to a node |
| `make output` | IDs and IPs |
| `make destroy` | delete the cluster (type `yes`) |
| `make help` | list all make commands |

**On slurm-master**:

| Command | What |
|---|---|
| `sinfo` | nodes and their state |
| `srun -N3 hostname` | run a command now, on 3 nodes |
| `srun --pty bash` | interactive shell on a node |
| `sbatch myjob.sh` | submit a script, runs in the background |
| `squeue` | running and waiting jobs |
| `scancel <jobid>` | cancel a job |
| `sacct` | job history |
| `scontrol show job <jobid>` | details of a job |
| `scontrol show node <node>` | details of a node |
| `exit` | back to the workstation |

**Daily routine:**

```
morning:  cd ~/workstation- && git pull && cd slurm
          make plan → make apply → (wait 2 min) → make ping → make ansible-slurm
work:     make ssh → sinfo / srun / sbatch / squeue / sacct → exit
evening:  make destroy → yes
```
