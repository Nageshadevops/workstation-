# Run from ~/workstation-/slurm on the workstation.
# -chdir=terraform runs every Terraform command inside the terraform/ folder.
TF := terraform -chdir=terraform

# SSH key for the Slurm servers. Created automatically by `make plan` if missing,
# kept across destroy/apply. Must match ssh_public_key_path in terraform.tfvars.
SSH_KEY := $(HOME)/.ssh/slurm-dev-key

.PHONY: help init fmt validate key plan apply destroy output

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
