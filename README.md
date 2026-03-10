# mypythonproject1-infra

Terraform infrastructure repository for AWS networking, compute, database, and deployment prerequisites.

## Provisioned resources

- VPC with public/private/db subnets
- ALB and listeners
- ECS cluster and services for backend/frontend
- RDS PostgreSQL
- IAM/OIDC resources for GitHub Actions deployment
- S3 Terraform state resources

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
│   ├── ecs-cluster/
│   ├── ecs-service/
│   ├── alb/
│   ├── rds/
│   └── iam/
├── .github/workflows/
│   ├── terraform.yml
│   ├── terraform-plan-reusable.yml
│   └── terraform-reusable.yml
├── .github/actions/
│   ├── terraform-common/
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

Main workflow: `.github/workflows/terraform.yml`

Shared workflow logic is implemented with composite actions:

- `.github/actions/terraform-common/action.yml`: Terraform setup, AWS OIDC auth, backend render, init/validate, optional security checks.
- `.github/actions/terraform-plan-common/action.yml`: Terraform plan, optional Infracost, plan artifact upload, optional PR comment.

CI Terraform version is pinned to `1.10.5` in the shared action because `use_lockfile` backend locking requires Terraform `1.10+`.

### PR opened to `main`

Promotion-style validation plans run in order:

1. `plan-dev`
2. `plan-staging`
3. `plan-prod`

Plan checks include:

- `terraform fmt -check`
- `terraform validate`
- `checkov`
- `tflint`
- `trivy`
- `terraform plan`

### After PR merge (`push` to `main`)

Promotion applies run in order:

1. `apply-dev`
2. `apply-staging` (after `apply-dev`)
3. `apply-prod` (after `apply-staging`)

Approval gates are controlled by GitHub Environments:

- `staging` environment approval gates `apply-staging`
- `prod` environment approval gates `apply-prod`

### Nightly drift detection

Scheduled jobs run drift plans for all environments:

- `drift-dev`
- `drift-staging`
- `drift-prod`

With `fail_on_drift: true`, a drift result fails that environment job and uploads artifacts for investigation.

## Required GitHub configuration

Repository variables:

- `AWS_REGION`

Repository/environment secrets:

- `AWS_OIDC_ROLE_ARN`
- `AWS_OIDC_ROLE_ARN_PLAN` (optional, dedicated plan role)
- `AWS_ROLE_TO_ASSUME` (legacy fallback)
- `AWS_ROLE_TO_ASSUME_PLAN` (legacy fallback)
- `TERRAFORM_STATE_BUCKET`
- `JWT_SECRET_KEY`
- `INFRACOST_API_KEY` (optional)

Create GitHub Environments:

- `dev`
- `staging`
- `prod`

Configure required reviewers on `staging` and `prod` for controlled promotion.

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
