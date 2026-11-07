# AWS Workstation Setup – Step-by-Step Record

**AWS Region:** Asia Pacific (Hyderabad) – `ap-south-2`  
**Operating System:** Red Hat Enterprise Linux 9.8  
**Instance Name:** `workstation-vm`  
**Purpose:** Linux administration, AWS CLI, Terraform, Ansible and future Slurm cluster administration.

This document records the AWS infrastructure creation, EC2 configuration, SSH setup, troubleshooting and software installation.

---

# PART 1 – AWS INFRASTRUCTURE SETUP

## 1. Create the VPC

In the AWS Console:

1. Open **VPC**.
2. Select **Your VPCs → Create VPC**.
3. Choose **VPC only**.
4. Enter:
   - Name: `workstation-vpc`
   - IPv4 CIDR: `172.22.0.0/16`
5. Enable DNS resolution and DNS hostnames.
6. Create the VPC.

Created resource:

| Setting | Value |
|---|---|
| VPC Name | `workstation-vpc` |
| VPC ID | `vpc-048b5c867ebd27427` |
| CIDR | `172.22.0.0/16` |

## 2. Create the Public Subnet

1. Open **VPC → Subnets → Create subnet**.
2. Select `workstation-vpc`.
3. Enter:
   - Name: `workstation-public-subnet`
   - Availability Zone: `ap-south-2a`
   - IPv4 CIDR: `172.22.7.0/24`
4. Create the subnet.
5. Select the subnet → **Actions → Edit subnet settings**.
6. Enable **Auto-assign public IPv4 address** and save.

Created resource:

| Setting | Value |
|---|---|
| Subnet Name | `workstation-public-subnet` |
| Subnet ID | `subnet-013a5b6e081ff7e64` |
| CIDR | `172.22.7.0/24` |
| Availability Zone | `ap-south-2a` |

## 3. Create and Attach the Internet Gateway

1. Open **VPC → Internet Gateways → Create internet gateway**.
2. Name it `workstation-igw`.
3. Create it.
4. Select it → **Actions → Attach to a VPC**.
5. Select `workstation-vpc` and attach it.

Created resource:

| Setting | Value |
|---|---|
| Internet Gateway Name | `workstation-igw` |
| Internet Gateway ID | `igw-09d481a18c01d14fa` |

## 4. Configure the Route Table

1. Open **VPC → Route Tables**.
2. Select the main route table for `workstation-vpc`.
3. Open **Routes → Edit routes**.
4. Keep the local route and add:
   - Destination: `0.0.0.0/0`
   - Target: `workstation-igw`
5. Save changes.
6. Confirm that the public subnet uses this route table.

Route table:

| Destination | Target | Status |
|---|---|---|
| `172.22.0.0/16` | `local` | Active |
| `0.0.0.0/0` | `igw-09d481a18c01d14fa` | Active |

Route Table ID: `rtb-0e4180b3f38f6c830`

## 5. Create the Workstation Security Group

1. Open **EC2 → Security Groups → Create security group**.
2. Enter:
   - Name: `workstation-sg`
   - Description: `SSH access for admin workstation`
   - VPC: `workstation-vpc`
3. Add inbound SSH access:
   - Type: SSH
   - Protocol: TCP
   - Port: `22`
   - Source: My IP
4. Keep the default outbound rule allowing all traffic.
5. Create the security group.

Security Group ID:

`sg-074f2b51a4e0aba0e`

### 5.1 Add EC2 Instance Connect Inbound Rule

The AWS Console EC2 Instance Connect service also needs to reach the instance on SSH port 22.

1. Open `workstation-sg` → **Inbound rules → Edit inbound rules**.
2. Add:
   - Type: SSH
   - Protocol: TCP
   - Port: `22`
   - Source: AWS-managed prefix list
     `com.amazonaws.ap-south-2.ec2-instance-connect`
3. Save the rules.

Correct prefix list:

`pl-0be6a5dd0f3c9573f`

Final inbound rules:

| Purpose | Type | Port | Source |
|---|---|---:|---|
| Laptop SSH | SSH | 22 | `106.51.254.150/32` |
| AWS Console EC2 Instance Connect | SSH | 22 | `pl-0be6a5dd0f3c9573f` |

**Important:** Do not use the VPC Lattice prefix list. Use only the prefix list named `com.amazonaws.ap-south-2.ec2-instance-connect` for this rule.

If your laptop's public IP changes, update the laptop `/32` rule.

## 6. Create the EC2 Key Pair

1. Open **EC2 → Network & Security → Key Pairs**.
2. Select **Create key pair**.
3. Name: `workstation-pem-key`.
4. Select PEM format.
5. Create and download the private key.
6. Keep the PEM file safe. AWS does not allow you to download the same private key again.

## 7. Launch the RHEL 9 EC2 Instance

1. Open **EC2 → Instances → Launch instances**.
2. Name: `workstation-vm`.
3. Select a Red Hat Enterprise Linux 9 AMI. The selected image was RHEL 9.8.
4. Instance type: `t3.small`.
5. Select key pair: `workstation-pem-key`.
6. Under Network Settings:
   - VPC: `workstation-vpc`
   - Subnet: `workstation-public-subnet`
   - Auto-assign public IP: Enabled
   - Security group: `workstation-sg`
7. Require IMDSv2.
8. No IAM instance role was attached.
9. Launch the instance.

Instance details:

| Setting | Value |
|---|---|
| Instance Name | `workstation-vm` |
| Instance ID | `i-092758e7a8867791c` |
| AMI ID | `ami-06580d145e90b0e99` |
| OS | RHEL 9.8 |
| Instance Type | `t3.small` |
| Private IP | `172.22.7.185` |
| VPC | `vpc-048b5c867ebd27427` |
| Subnet | `subnet-013a5b6e081ff7e64` |

**Storage:** The original plan was a 20 GiB encrypted gp3 root disk. Actual disk settings still need verification in EC2 → Instances → Storage.

## 8. Allocate and Associate an Elastic IP

1. Open **EC2 → Network & Security → Elastic IPs**.
2. Select **Allocate Elastic IP address**.
3. Allocate the address.
4. Select it → **Actions → Associate Elastic IP address**.
5. Select `workstation-vm`.
6. Select private IP `172.22.7.185`.
7. Associate it.

Elastic IP details:

| Setting | Value |
|---|---|
| Public IP | `16.112.184.161` |
| Allocation ID | `eipalloc-0fa742da4fd3360eb` |
| Association ID | `eipassoc-0b4b57550e59c9b03` |
| Instance | `i-092758e7a8867791c` |

Use the Elastic IP for SSH connections.

## 9. Connect from Windows Laptop Using WSL

The key file was downloaded to the Windows Downloads folder.

Example commands in WSL (change the Windows username/path if required):

```bash
mkdir -p ~/.ssh

cp /mnt/c/Users/localcontrol/Downloads/workstation-pem-key.pem ~/.ssh/

chmod 400 ~/.ssh/workstation-pem-key.pem
```

Connect to the EC2 instance:

```bash
ssh -i ~/.ssh/workstation-pem-key.pem ec2-user@16.112.184.161
```

Default RHEL EC2 username: `ec2-user`.

**Verified:** SSH from WSL to the EC2 instance works.

---

# PART 2 – EC2 INSTANCE CONNECT TROUBLESHOOTING

## 10. Initial Connection Problem

WSL SSH was working, but AWS Console → EC2 → Connect → EC2 Instance Connect showed:

```text
Failed to connect to your instance.

Error establishing SSH connection to your instance.
Try again later.
```

## 10.1 Correct the Security Group Rule

Initially, an incorrect VPC Lattice prefix list was selected.

It was replaced with:

```text
com.amazonaws.ap-south-2.ec2-instance-connect
```

The laptop SSH rule was retained.

## 10.2 Check EC2 Instance Connect Package

Run:

```bash
rpm -q ec2-instance-connect
```

Initial output:

```text
package ec2-instance-connect is not installed
```

## 10.3 Install EC2 Instance Connect on RHEL 9

The package was not available by name in the configured RHEL 9 repositories.

Download the AWS RPM packages.

Create a temporary directory:

```bash
mkdir -p /tmp/ec2-instance-connect
```

Download the main package:

```bash
curl https://amazon-ec2-instance-connect-us-west-2.s3.us-west-2.amazonaws.com/latest/linux_amd64/ec2-instance-connect-2.0.0-6.rhel9.x86_64.rpm -o /tmp/ec2-instance-connect/ec2-instance-connect.rpm
```

Download the SELinux package:

```bash
curl https://amazon-ec2-instance-connect-us-west-2.s3.us-west-2.amazonaws.com/latest/linux_amd64/ec2-instance-connect-selinux-2.0.0-6.noarch.rpm -o /tmp/ec2-instance-connect/ec2-instance-connect-selinux.rpm
```

Install both packages:

```bash
sudo dnf install -y /tmp/ec2-instance-connect/*.rpm
```

Installed packages:

```text
ec2-instance-connect-2.0.0-6.rhel9.x86_64
ec2-instance-connect-selinux-2.0.0-6.noarch
```

Installation completed successfully.

## 10.4 Verify SSH Authorized Keys Configuration

Run:

```bash
sudo sshd -T | grep -i authorizedkeyscommand
```

Verified output:

```text
authorizedkeyscommand /opt/aws/bin/eic_run_authorized_keys %u %f
authorizedkeyscommanduser ec2-instance-connect
```

Also verified:

```bash
sudo sshd -T | grep -i authorizedkeyscommanduser
```

Output:

```text
authorizedkeyscommanduser ec2-instance-connect
```

## 10.5 Verify AWS Console Connection

1. Open EC2 → Instances.
2. Select `workstation-vm`.
3. Click **Connect**.
4. Select **EC2 Instance Connect**.
5. Username: `ec2-user`.
6. Click **Connect**.

**Verified:** AWS Console EC2 Instance Connect now works.

Successful shell prompt:

```text
[ec2-user@ip-172-22-7-185 ~]$
```

## 11. Red Hat Registration Message

At login, RHEL may display:

```text
Register this system with Red Hat Insights: rhc connect
```

This is an informational message asking to connect the machine to Red Hat Insights.

It is not an SSH error and does not prevent the workstation from working.

No registration was performed as part of this setup.

---

# PART 3 – SOFTWARE INSTALLATION

All software installation commands below were run using the `root` account.

## 12. Update RHEL System Packages

Command:

```bash
sudo dnf update -y
```

Purpose:

- Update installed Linux packages.
- Apply available security updates.
- Update system components and kernel.

**Status:** Completed successfully.

## 13. Install Basic Linux Utilities

Command:

```bash
sudo dnf install -y git make unzip vim tmux jq bash-completion wget curl
```

Installed software:

| Software | Verified Version / Status |
|---|---|
| Git | 2.52.0 |
| Make | 4.3 |
| Vim | 8.2 |
| Tmux | 3.2a |
| jq | 1.6 |
| Unzip | Installed |
| Bash completion | Installed |
| Wget | Installed |
| Curl | Installed |

Verification commands:

```bash
git --version

make --version

vim --version | head -1

tmux -V

jq --version
```

**Status:** Completed successfully.

## 14. Install Python 3.11 and pip

Command:

```bash
sudo dnf install -y python3.11 python3.11-pip
```

Installed versions:

- Python: `3.11.13`
- pip: `22.3.1`

Verification:

```bash
python3.11 --version

python3.11 -m pip --version
```

**Status:** Completed successfully.

## 15. Install AWS CLI v2

### Download AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
```

### Extract the installer

```bash
unzip awscliv2.zip
```

### Install AWS CLI

```bash
sudo ./aws/install
```

AWS CLI executable location:

```text
/usr/local/bin/aws
```

Initially, the command was not found because `/usr/local/bin` was missing from the root user's PATH.

### Fix PATH

```bash
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc

source ~/.bashrc
```

### Verify AWS CLI

```bash
aws --version
```

Installed version:

```text
aws-cli/2.39.5
```

**Status:** Completed successfully.

## 16. Install Terraform

### Install DNF plugins

```bash
sudo dnf install -y dnf-plugins-core
```

### Add official HashiCorp repository

```bash
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
```

### Install Terraform

```bash
sudo dnf install -y terraform
```

### Verify Terraform

```bash
terraform --version
```

Installed version:

```text
Terraform v1.17.1
on linux_amd64
```

**Status:** Completed successfully.

## 17. Install Ansible

Install Ansible using Python 3.11 pip:

```bash
python3.11 -m pip install ansible
```

### Verify Ansible

```bash
ansible --version
```

Installed versions:

| Component | Version |
|---|---|
| Ansible | 12.3.0 |
| Ansible Core | 2.19.15 |
| Python | 3.11.13 |
| Jinja | 3.1.6 |

**Status:** Completed successfully.

**Note:** pip displayed a warning about running as root. For future Python packages, prefer a virtual environment or install under the intended non-root administrator account.

---

# PART 4 – SOFTWARE INSTALLATION SUMMARY

## 18. Installed Software Inventory

| Sl. No. | Software | Version / Status | Installation Method |
|---:|---|---|---|
| 1 | Git | 2.52.0 | DNF |
| 2 | Make | 4.3 | DNF |
| 3 | Vim | 8.2 | DNF |
| 4 | Tmux | 3.2a | DNF |
| 5 | jq | 1.6 | DNF |
| 6 | Unzip | Installed | DNF |
| 7 | Bash completion | Installed | DNF |
| 8 | Wget | Installed | DNF |
| 9 | Curl | Installed | DNF |
| 10 | Python | 3.11.13 | DNF |
| 11 | pip | 22.3.1 | DNF |
| 12 | AWS CLI | 2.39.5 | Official AWS installer |
| 13 | Terraform | 1.17.1 | HashiCorp repository |
| 14 | Ansible | 12.3.0 | Python pip |

## 19. General Software Verification Commands

Use these commands to check all installed software:

```bash
git --version

make --version

vim --version | head -1

tmux -V

jq --version

python3.11 --version

python3.11 -m pip --version

aws --version

terraform --version

ansible --version
```

---

# PART 5 – CURRENT SETUP STATUS

## 20. Completed and Pending Tasks

| Item | Status |
|---|---|
| VPC creation | Completed |
| Public subnet creation | Completed |
| Internet Gateway attachment | Completed |
| Route table configuration | Completed |
| Workstation security group | Completed |
| Laptop SSH inbound rule | Completed |
| EC2 Instance Connect prefix-list rule | Completed |
| EC2 key pair | Created |
| RHEL 9.8 EC2 instance | Launched |
| Elastic IP | Allocated and associated |
| WSL SSH connection | Tested successfully |
| EC2 Instance Connect RPM installation | Completed |
| SSH authorized-keys configuration | Verified |
| AWS Console EC2 Instance Connect | Working |
| RHEL system update | Completed |
| Basic Linux utilities | Installed |
| Python 3.11 and pip | Installed |
| AWS CLI v2 | Installed |
| Terraform | Installed |
| Ansible | Installed |
| `prasanna` admin account | Pending |
| Hostname change to `workstation` | Pending |
| SSH access for `prasanna` | Pending |
| Sudo verification for `prasanna` | Pending |
| AWS credentials configuration | Pending |
| EBS root volume size and encryption verification | Pending |
| EC2 termination protection | Not confirmed |
| Remaining security hardening | Pending |

---

# PART 6 – NEXT PLANNED STEPS

## 21. Create the Linux Administrator Account

Planned Linux administrator username:

```text
prasanna
```

The account has not yet been created.

Planned activities:

1. Create the `prasanna` user.
2. Add the user to the `wheel` group.
3. Set a strong password.
4. Configure SSH key access.
5. Test SSH login using `prasanna`.
6. Verify sudo access using `sudo whoami`.
7. Retain `ec2-user` as a backup login.

## 22. Configure Hostname

Planned hostname:

```text
workstation
```

Command to execute later:

```bash
sudo hostnamectl set-hostname workstation
```

Verify:

```bash
hostnamectl
```

## 23. Configure AWS Credentials

AWS CLI credentials have not yet been configured.

Preferred approach:

- Use a suitably scoped IAM role if the AWS administrator can provide one.
- If an IAM role is unavailable, configure approved AWS access credentials under the `prasanna` account.

Never store AWS access keys in Git repositories or share them publicly.

## 24. Verify EC2 Storage and Protection

Pending verification:

- Root EBS volume size: intended 20 GiB.
- Volume type: intended gp3.
- Encryption: intended enabled.
- EC2 termination protection: enable and verify.

Check these settings in the AWS Console under EC2 → Instances → Storage and Instance settings.

## 25. Remaining Workstation Security Configuration

Planned activities:

- Configure SSH security settings.
- Disable root SSH login.
- Keep key-based SSH access working.
- Configure the required authentication method for `prasanna`.
- Test all SSH settings before restarting the SSH service.
- Keep the existing `ec2-user` login until the new account is tested.

---

# SECURITY REMINDERS

1. Keep the PEM private key secure.
2. Do not share AWS access keys.
3. Do not commit AWS credentials to Git.
4. Restrict SSH access to trusted source IPs.
5. Keep a working backup SSH login.
6. Test new SSH settings before closing the existing session.
7. Verify disk encryption and EC2 termination protection.

---

**Document Status:** AWS infrastructure and initial workstation software installation completed. Linux administrator account and remaining workstation configuration are pending.

------------------------------------------

Attach iam role with below policy to create the infra through terrafrom via workstation vm

---------
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "SlurmTerraformEC2Management",
			"Effect": "Allow",
			"Action": [
				"ec2:CreateVpc",
				"ec2:DeleteVpc",
				"ec2:ModifyVpcAttribute",
				"ec2:CreateSubnet",
				"ec2:DeleteSubnet",
				"ec2:CreateInternetGateway",
				"ec2:AttachInternetGateway",
				"ec2:DetachInternetGateway",
				"ec2:DeleteInternetGateway",
				"ec2:CreateRouteTable",
				"ec2:DeleteRouteTable",
				"ec2:CreateRoute",
				"ec2:DeleteRoute",
				"ec2:AssociateRouteTable",
				"ec2:DisassociateRouteTable",
				"ec2:AllocateAddress",
				"ec2:ReleaseAddress",
				"ec2:CreateNatGateway",
				"ec2:DeleteNatGateway",
				"ec2:CreateSecurityGroup",
				"ec2:DeleteSecurityGroup",
				"ec2:AuthorizeSecurityGroupIngress",
				"ec2:AuthorizeSecurityGroupEgress",
				"ec2:RevokeSecurityGroupIngress",
				"ec2:RevokeSecurityGroupEgress",
				"ec2:ModifySecurityGroupRules",
				"ec2:CreateVpcPeeringConnection",
				"ec2:AcceptVpcPeeringConnection",
				"ec2:DeleteVpcPeeringConnection",
				"ec2:ImportKeyPair",
				"ec2:DeleteKeyPair",
				"ec2:RunInstances",
				"ec2:TerminateInstances",
				"ec2:CreateNetworkInterface",
				"ec2:DeleteNetworkInterface",
				"ec2:CreateVolume",
				"ec2:DeleteVolume",
				"ec2:CreateTags",
				"ec2:DeleteTags"
			],
			"Resource": "*",
			"Condition": {
				"StringEquals": {
					"aws:RequestedRegion": "ap-south-2"
				}
			}
		},
		{
			"Sid": "SlurmTerraformEC2Read",
			"Effect": "Allow",
			"Action": [
				"ec2:Describe*"
			],
			"Resource": "*",
			"Condition": {
				"StringEquals": {
					"aws:RequestedRegion": "ap-south-2"
				}
			}
		}
	]
}