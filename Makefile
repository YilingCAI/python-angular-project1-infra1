SHELL := /bin/bash

TERRAFORM ?= terraform
BOOTSTRAP_DIR := bootstrap
AWS_LOCAL_ENV_FILE ?= .aws.local.env
BOOTSTRAP_TFVARS_REL ?= env/bootstrap.tfvars
TFVARS_FILE := $(BOOTSTRAP_DIR)/$(BOOTSTRAP_TFVARS_REL)
TF_DATA_DIR := .terraform

.PHONY: bootstrap bootstrap-init bootstrap-plan bootstrap-apply bootstrap-destroy bootstrap-import-existing

bootstrap: bootstrap-apply

define require_aws_env_file
	@[ -f "$(AWS_LOCAL_ENV_FILE)" ] || { \
		echo "Error: missing AWS env file: $(AWS_LOCAL_ENV_FILE)"; \
		echo "Create it with AWS credentials and region variables."; \
		exit 1; \
	}
endef

define require_bootstrap_tfvars
	@[ -f "$(TFVARS_FILE)" ] || { \
		echo "Error: tfvars file not found: $(TFVARS_FILE)"; \
		exit 1; \
	}
endef

define load_aws_env
set -a; \
source "$(AWS_LOCAL_ENV_FILE)"; \
set +a;
endef

define check_aws_identity
AWS_PAGER="" aws sts get-caller-identity >/dev/null || { \
	echo "Error: AWS authentication failed using $(AWS_LOCAL_ENV_FILE)."; \
	exit 1; \
};
endef

bootstrap-init:
	@$(call require_bootstrap_tfvars)
	@$(call require_aws_env_file)
	@echo "Initializing bootstrap"
	@$(load_aws_env) $(check_aws_identity) cd "$(BOOTSTRAP_DIR)" && TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) init

bootstrap-plan:
	@$(call require_bootstrap_tfvars)
	@$(call require_aws_env_file)
	@echo "Planning bootstrap"
	@$(load_aws_env) $(check_aws_identity) cd "$(BOOTSTRAP_DIR)" && TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) init -input=false -upgrade && TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) plan -var-file="$(BOOTSTRAP_TFVARS_REL)"

bootstrap-import-existing:
	@$(call require_bootstrap_tfvars)
	@$(call require_aws_env_file)
	@echo "Importing existing bootstrap resources (best effort)"
	@$(load_aws_env) $(check_aws_identity) \
		set -e; \
		cd "$(BOOTSTRAP_DIR)"; \
		TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) init -input=false -upgrade >/dev/null; \
		ACCOUNT_ID=$$(AWS_PAGER="" aws sts get-caller-identity --query Account --output text); \
		set +e; \
		for env in dev staging prod; do \
		  TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" "aws_s3_bucket.terraform_state[\"$$env\"]" "mypythonproject1-tfstate-$$env" >/dev/null 2>&1 || true; \
		  TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" "aws_s3_bucket_versioning.terraform_state[\"$$env\"]" "mypythonproject1-tfstate-$$env" >/dev/null 2>&1 || true; \
		  TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" "aws_s3_bucket_server_side_encryption_configuration.terraform_state[\"$$env\"]" "mypythonproject1-tfstate-$$env" >/dev/null 2>&1 || true; \
		  TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" "aws_s3_bucket_public_access_block.terraform_state[\"$$env\"]" "mypythonproject1-tfstate-$$env" >/dev/null 2>&1 || true; \
		  TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" "aws_dynamodb_table.terraform_lock[\"$$env\"]" "mypythonproject1-terraform-lock-$$env" >/dev/null 2>&1 || true; \
		done; \
		TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" aws_ecr_repository.backend mypythonproject1/backend >/dev/null 2>&1 || true; \
		TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" aws_ecr_repository.frontend mypythonproject1/frontend >/dev/null 2>&1 || true; \
		TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" aws_iam_openid_connect_provider.github "arn:aws:iam::$$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" >/dev/null 2>&1 || true; \
		TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" aws_iam_role.github_actions GitHubActionsRole >/dev/null 2>&1 || true; \
		TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) import -var-file="$(BOOTSTRAP_TFVARS_REL)" aws_iam_role_policy.github_actions GitHubActionsRole:GitHubActionsPolicy >/dev/null 2>&1 || true; \
		echo "Import phase complete."

bootstrap-apply:
	@$(call require_bootstrap_tfvars)
	@$(call require_aws_env_file)
	@echo "Applying bootstrap"
	@$(MAKE) bootstrap-import-existing
	@$(load_aws_env) $(check_aws_identity) cd "$(BOOTSTRAP_DIR)" && TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) apply -var-file="$(BOOTSTRAP_TFVARS_REL)" -auto-approve

bootstrap-destroy:
	@$(call require_bootstrap_tfvars)
	@$(call require_aws_env_file)
	@echo "Destroying bootstrap"
	@$(load_aws_env) $(check_aws_identity) cd "$(BOOTSTRAP_DIR)" && TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) init -input=false -upgrade && TF_DATA_DIR="$(TF_DATA_DIR)" $(TERRAFORM) destroy -var-file="$(BOOTSTRAP_TFVARS_REL)" -auto-approve
