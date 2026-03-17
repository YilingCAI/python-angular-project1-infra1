# mypythonproject1-infra

Terraform infrastructure repository for AWS networking, compute, database, and deployment prerequisites.

## Provisioned resources

- VPC with public/private/db subnets
- ALB and listeners
- ECS cluster and services for backend/frontend
- RDS PostgreSQL
- IAM/OIDC resources for GitHub Actions deployment
- S3 Terraform state resources

## Architecture Overview

### 2.1 Shared Components

- Networking: VPC per infra, multi-AZ subnets, NAT gateway, private/public segregation.
- IAM: least privilege, separate roles per CI/CD, per service, per environment.
- Logging and Monitoring: CloudWatch for all infra; Prometheus and Grafana for EKS-based observability where applicable.
- Security: encrypted RDS and ECR, security groups per service, CloudTrail and GuardDuty.

### 2.2 Fargate Infra

```text
					+-------------------------+
					|        ALB              |
					+-----------+-------------+
											|
					 +----------+----------+
					 | ECS Cluster (Fargate)|
					 +----+----------+-----+
					 |    |          |     |
			 Backend Frontend  Workers  # optional
					|     |          |
				 ECR   ECR        ECR
					|
				CloudWatch logs
					|
				 RDS (private)
```

## Repository layout

```text
.
├── bootstrap/
│   ├── env/
│   │   └── bootstrap.tfvars
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── ecs-service/
│   ├── alb/
│   ├── monitoring/
│   ├── rds/
│   └── iam/
├── .github/workflows/
│   ├── terraform-plan-speculative.yml
│   ├── terraform-plan-apply.yml
│   ├── terraform-drift.yml
│   ├── terraform-plan-reusable.yml
│   └── terraform-apply-reusable.yml
├── .github/actions/
│   ├── terraform-setup-common/
│   │   └── action.yml
│   └── terraform-plan-common/
│       └── action.yml
└── Makefile
```

## State and locking model

Each environment uses isolated remote state in S3 with backend lockfiles enabled:

- `dev`: `mypythonproject1-tfstate-dev`
- `staging`: `mypythonproject1-tfstate-staging`
- `prod`: `mypythonproject1-tfstate-prod`

`backend.hcl` files are rendered during CI and for local use contain:

```hcl
bucket         = "<env-state-bucket>"
key            = "<env>/terraform.tfstate"
region         = "us-east-1"
use_lockfile   = true
encrypt        = true
```

## Bootstrap (per AWS account)

Bootstrap creates shared foundation resources (state buckets, OIDC role/provider, ECR repos).

Run from repo root:

```bash
make bootstrap-init
make bootstrap-plan
make bootstrap-apply
```

Bootstrap variables are in `bootstrap/env/bootstrap.tfvars`.

## Local AWS credentials (safe setup)

This repo uses a local file named `.aws.local.env` for bootstrap-related AWS credentials.

1. Create your local file from the template:

```bash
cp .aws.local.env.example .aws.local.env
```

2. Edit `.aws.local.env` with real values from your AWS account.

3. If you use temporary credentials, set `AWS_SESSION_TOKEN` as well.

Security note:

- `.aws.local.env` is intentionally gitignored.
- Never commit real credentials to git history.

## CI/CD flow

Top-level workflows:

- .github/workflows/terraform-plan-speculative.yml
- .github/workflows/terraform-plan-apply.yml
- .github/workflows/terraform-drift.yml

Shared workflow logic is implemented with composite actions:

- .github/actions/terraform-setup-common/action.yml: Terraform setup, AWS OIDC auth, backend render, init/validate, optional security checks.
- .github/actions/terraform-plan-common/action.yml: Terraform plan (speculative, real, or drift), optional Infracost, plan artifact upload, optional PR comment.

terraform-setup-common restores cache for Terraform providers/modules (~/.terraform.d/plugin-cache, environments/<env>/.terraform) and TFLint plugins (~/.tflint.d/plugins) to speed repeated workflow runs.

CI Terraform version is pinned to `1.10.5` in the shared action because `use_lockfile` backend locking requires Terraform `1.10+`.

### PR opened to `main`

Speculative validation plans run in order through .github/workflows/terraform-plan-speculative.yml:

1. `plan-dev`
2. `plan-staging`
3. `plan-prod`

These run with `speculative_plan: true` (no saved plan artifact for apply handoff and no state lock).
Speculative PR plans run without GitHub Environment assignment.

Plan checks include:

- `terraform fmt -check`
- `terraform validate`
- `checkov`
- `tflint`
- `trivy`
- `terraform plan`

Note: `terraform-setup-common` supports `checkov_enforcement` with `advisory` (default, soft-fail) or `blocking`.

Terraform var-file handling is automatic per environment: if `environments/<env>/terraform.tfvars` exists it is used; otherwise plan/drift/apply run without `-var-file`.

To reduce transient lock contention with `use_lockfile`, plan/drift/apply use `-lock-timeout=5m` in CI.

### After PR merge (`push` to `main`)

Promotion workflow runs through .github/workflows/terraform-plan-apply.yml.

Triggers:

- push to main for Terraform path changes
- workflow_dispatch for manual plan/apply
- workflow_run on successful Terraform Plan Speculative completion

Plan and apply sequence:

1. `plan-dev` then `apply-dev`
2. `plan-staging` then `apply-staging`
3. `plan-prod` then `apply-prod`

Apply jobs reuse saved real-plan artifacts and execute apply from tfplan.binary.
Artifact handoff is deterministic by passing plan artifact ID from plan job output to apply job input.

Each apply performs a pre-apply drift detection plan (-detailed-exitcode).

- default behavior: abort on drift
- manual dev override: set workflow_dispatch input dev_allow_apply_on_drift=true to continue in dev

Approval gates are controlled by GitHub Environments:

- `staging` environment approval gates `apply-staging`
- `prod` environment approval gates `apply-prod`

### Nightly drift detection

Scheduled drift workflow runs through .github/workflows/terraform-drift.yml.

Jobs run in order for all environments:

- `drift-dev`
- `drift-staging`
- `drift-prod`

With `fail_on_drift: true`, a drift result fails that environment job and uploads artifacts for investigation.

## Required GitHub configuration

Repository variables:

- `AWS_REGION`

Repository/environment secrets:

- `AWS_OIDC_ROLE_ARN`
- `TERRAFORM_STATE_BUCKET`
- `JWT_SECRET_KEY`
- `INFRACOST_API_KEY` (optional)

Create GitHub Environments:

- `dev`
- `staging`
- `prod`

Configure required reviewers on `staging` and `prod` for controlled promotion.

Recommended:

- Keep required reviewers on prod to enforce manual approval before production apply.
- Keep OIDC role least-privilege scoped per environment.

## Local validation

```bash
terraform fmt -check -recursive
terraform -chdir=environments/dev validate
terraform -chdir=environments/staging validate
terraform -chdir=environments/prod validate
```

## Dependabot

Dependabot config: `.github/dependabot.yml`.

Dependabot opens update PRs, then the same PR validation and promotion controls apply.
