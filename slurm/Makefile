# Run from ~/workstation-/slurm on the workstation.
# -chdir=terraform runs every Terraform command inside the terraform/ folder.
TF := terraform -chdir=terraform

.PHONY: help init fmt validate plan apply destroy output

help:
	@echo "Usage: make <target>"
	@echo "  init      download the AWS provider (run once, and after adding providers)"
	@echo "  fmt       format all .tf files"
	@echo "  validate  check the code for errors (no AWS calls)"
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

plan:
	$(TF) plan -out=tfplan

apply:
	$(TF) apply tfplan

destroy:
	$(TF) destroy

output:
	$(TF) output
