###############################################################################
# Makefile — Terraform operations for mypythonproject1-infra
###############################################################################

.PHONY: help tf-fmt tf-validate tf-init tf-plan tf-apply tf-destroy workflow-check

AWS_REGION ?= us-east-1
ENV ?= staging
TERRAFORM_STATE_BUCKET ?=
TERRAFORM_LOCK_TABLE ?= terraform-locks
TFVARS_FILE := envs/$(ENV).tfvars
WORKFLOW_FILE := .github/workflows/terraform-infra.yml
README_FILE := README.md

help:
	@echo ""
	@echo "Terraform Makefile (mypythonproject1-infra)"
	@echo ""
	@echo "Usage:"
	@echo "  make tf-validate"
	@echo "  make tf-plan ENV=staging TERRAFORM_STATE_BUCKET=<bucket>"
	@echo "  make tf-apply ENV=staging TERRAFORM_STATE_BUCKET=<bucket>"
	@echo "  make tf-destroy ENV=staging TERRAFORM_STATE_BUCKET=<bucket>"
	@echo "  make workflow-check"
	@echo ""
	@echo "Required for init/plan/apply/destroy: TERRAFORM_STATE_BUCKET, TERRAFORM_LOCK_TABLE"

_require_bucket:
	@if [ -z "$(TERRAFORM_STATE_BUCKET)" ]; then \
		echo "❌ TERRAFORM_STATE_BUCKET is required"; \
		echo "   Example: make tf-plan ENV=staging TERRAFORM_STATE_BUCKET=my-tf-state-bucket"; \
		exit 1; \
	fi

_require_tfvars:
	@if [ ! -f "$(TFVARS_FILE)" ]; then \
		echo "❌ Missing tfvars file: $(TFVARS_FILE)"; \
		exit 1; \
	fi

tf-fmt:
	terraform fmt -check -recursive

tf-validate:
	terraform init -backend=false -upgrade
	terraform validate

tf-init: _require_bucket
	terraform init \
		-backend-config="bucket=$(TERRAFORM_STATE_BUCKET)" \
		-backend-config="key=$(ENV)/terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TERRAFORM_LOCK_TABLE)" \
		-upgrade

tf-plan: _require_bucket _require_tfvars
	terraform init \
		-backend-config="bucket=$(TERRAFORM_STATE_BUCKET)" \
		-backend-config="key=$(ENV)/terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TERRAFORM_LOCK_TABLE)" \
		-upgrade
	terraform plan -var-file="$(TFVARS_FILE)"

tf-apply: _require_bucket _require_tfvars
	terraform init \
		-backend-config="bucket=$(TERRAFORM_STATE_BUCKET)" \
		-backend-config="key=$(ENV)/terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TERRAFORM_LOCK_TABLE)" \
		-upgrade
	terraform apply -var-file="$(TFVARS_FILE)" -auto-approve -input=false

tf-destroy: _require_bucket _require_tfvars
	terraform init \
		-backend-config="bucket=$(TERRAFORM_STATE_BUCKET)" \
		-backend-config="key=$(ENV)/terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TERRAFORM_LOCK_TABLE)" \
		-upgrade
	terraform destroy -var-file="$(TFVARS_FILE)" -auto-approve

workflow-check:
	@test -f "$(WORKFLOW_FILE)" || (echo "❌ Missing workflow: $(WORKFLOW_FILE)"; exit 1)
	@test -f "$(README_FILE)" || (echo "❌ Missing README: $(README_FILE)"; exit 1)
	@if command -v ruby >/dev/null 2>&1; then \
		ruby -e 'require "yaml"; YAML.load_file(ARGV[0]); puts "✓ Workflow YAML parses"' "$(WORKFLOW_FILE)"; \
	else \
		echo "⚠️ ruby not found; skipping YAML parse check"; \
	fi
	@for key in AWS_ROLE_TO_ASSUME TERRAFORM_STATE_BUCKET TERRAFORM_LOCK_TABLE JWT_SECRET_KEY AWS_REGION; do \
		grep -q "$$key" "$(WORKFLOW_FILE)" || (echo "❌ Missing $$key in $(WORKFLOW_FILE)"; exit 1); \
		grep -q "$$key" "$(README_FILE)" || (echo "❌ Missing $$key in $(README_FILE)"; exit 1); \
	done
	@echo "✅ workflow-check passed"
