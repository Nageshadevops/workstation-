# Run from ~/workstation-/slurm on the workstation.
# -chdir=terraform runs every Terraform command inside the terraform/ folder.
TF := terraform -chdir=terraform

# SSH key for the Slurm servers. Created automatically by `make plan` if missing,
# kept across destroy/apply. Must match ssh_public_key_path in terraform.tfvars.
SSH_KEY := $(HOME)/.ssh/slurm-dev-key

# Server for `make ssh`; override with: make ssh HOST=slurm-node-1
HOST ?= slurm-master

# Ansible reads ansible/ansible.cfg (set explicitly, so it never depends on the folder).
ANSIBLE := cd ansible && ANSIBLE_CONFIG=ansible.cfg

.PHONY: help init fmt validate key plan apply destroy output ssh inventory ping ansible-slurm

help:
	@echo "Usage: make <target>"
	@echo "  init      download the AWS provider (run once, and after adding providers)"
	@echo "  fmt       format all .tf files"
	@echo "  validate  check the code for errors (no AWS calls)"
	@echo "  key       create the Slurm SSH key $(SSH_KEY) if it does not exist"
	@echo "  plan      show what would change and save it to terraform/tfplan"
	@echo "  apply     apply the saved plan (run make plan first)"
	@echo "  destroy   delete everything Terraform created"
	@echo "  output    show the outputs (IDs, IPs, ...)"
	@echo "  ssh       log in to a Slurm server: make ssh [HOST=slurm-node-1]"
	@echo "  inventory write ansible/inventory.ini from the Terraform outputs"
	@echo "  ping      check that Ansible can reach and log in to every server"
	@echo "  ansible-slurm  run the Slurm playbook; options: ARGS=\"--tags base\" or ARGS=\"--check --diff\""

init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

key: $(SSH_KEY).pub

# Runs only when the .pub file does not exist yet. -N "" = no passphrase (Ansible needs that).
$(SSH_KEY).pub:
	mkdir -p -m 700 $(HOME)/.ssh
	ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -C "slurm-dev"

plan: key
	$(TF) plan -out=tfplan

apply:
	$(TF) apply tfplan

destroy:
	$(TF) destroy

output:
	$(TF) output

# Looks up the private IP in the Terraform outputs, so it works after every re-create.
# Servers get new host keys on every re-create, so known_hosts is not used (lab only,
# private network reachable only from the workstation).
ssh:
	ssh -i $(SSH_KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	  ec2-user@$$($(TF) output -json instances | jq -r '."$(HOST)".private_ip')

# ---------------------------------------------------------------------------
# Ansible (stage 3)
# ---------------------------------------------------------------------------
inventory:
	bash ansible/make-inventory.sh

ping: inventory
	$(ANSIBLE) ansible all -m ping

ansible-slurm: inventory
	$(ANSIBLE) ansible-playbook slurm.yml $(ARGS)
