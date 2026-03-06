<<<<<<< HEAD
# python-devops-aws-project1-infra
Terrafrom 
=======
# mypythonproject1-infra

Terraform infrastructure repository for AWS networking, compute, database, and deployment prerequisites.

## Provisioned resources

- VPC + public/private/db subnets
- ALB and listeners
- ECS cluster/services for backend and frontend
- RDS PostgreSQL
- IAM roles/policies needed by workloads

## Repository layout

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── backend-config.hcl
├── envs/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
├── modules/
│   ├── network/
│   ├── alb/
│   ├── ecs/
│   ├── ecs_frontend/
│   └── rds/
├── bootstrap/
└── .github/workflows/terraform-infra.yml
```

## Backend state model

Terraform uses S3 remote state with DynamoDB state locking.

`backend-config.hcl`:

```hcl
bucket       = "myproject-terraform-state"
key          = "terraform.tfstate"
region       = "us-east-1"
encrypt      = true
dynamodb_table = "terraform-lock"
```

Manual init example:

```bash
terraform init \
  -backend-config="bucket=myproject-terraform-state" \
  -backend-config="key=staging/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-lock"
```

Use separate state keys per environment, for example:

- `dev/terraform.tfstate`
- `staging/terraform.tfstate`
- `prod/terraform.tfstate`

## First-time bootstrap (per AWS account)

1. Create S3 bucket for Terraform state (versioned + encrypted)
2. Create GitHub OIDC provider in IAM
3. Create IAM roles trusted for GitHub Environments (`staging`, `production`)
4. Create ECR repositories for backend/frontend

Bootstrap stack:

```bash
terraform -chdir=bootstrap init -upgrade
terraform -chdir=bootstrap apply
```

This runs the dedicated stack in `bootstrap/`.

## Local usage

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform plan -var-file="envs/staging.tfvars"
```

Or use Make targets from this repo root:

```bash
make tf-validate
make tf-plan ENV=staging TERRAFORM_STATE_BUCKET=<state-bucket>
make tf-apply ENV=staging TERRAFORM_STATE_BUCKET=<state-bucket>
make tf-destroy ENV=staging TERRAFORM_STATE_BUCKET=<state-bucket>
make workflow-check
```

Destroy:

```bash
terraform destroy -var-file="envs/staging.tfvars"
```

## GitHub Actions (infra-only)

Workflow: `.github/workflows/terraform-infra.yml`

- `pull_request` to `main`: `fmt`, `init`, `validate`, `plan`
- `push` to `main`: `apply` (gated by `production` environment approval)
- `workflow_dispatch`: choose `environment` (`staging` or `prod`) and `action` (`plan` or `apply`)
- `schedule` (nightly): drift-detection `plan` for `staging` and `prod`
- `apply` uses GitHub Environment protection

Required repository configuration:

- Secrets:
  - `AWS_ROLE_TO_ASSUME`
  - `AWS_ROLE_TO_ASSUME_PLAN` (optional, read-only role for PR plans)
  - `TERRAFORM_STATE_BUCKET`
  - `TERRAFORM_LOCK_TABLE`
  - `JWT_SECRET_KEY`
- Variables:
  - `AWS_REGION`

## Dependabot

Dependabot configuration is in `.github/dependabot.yml` and updates:

- Terraform providers/modules (including `.terraform.lock.hcl`)
- GitHub Actions versions

Recommended rollout pattern (dev-first, prod-late): merge dependency updates after validation in lower-risk environment first, then promote the same commit to production.

## Environment files

- `envs/staging.tfvars`: staging sizing/capacity
- `envs/prod.tfvars`: production sizing/capacity
- `envs/dev.tfvars`: developer/shared lower-cost setup

Note for `dev`: ECS desired counts are intentionally set to `0` so first-time `terraform apply` succeeds even before ECR images are pushed. After pushing images, scale up by setting `desired_count` / `frontend_desired_count` (and `min_capacity`) above `0`.

Keep shared structure in modules and only vary environment inputs in tfvars.
>>>>>>> c093ea3 (initial commit)
