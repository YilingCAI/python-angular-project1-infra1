# mypythonproject1-infra

Terraform infrastructure repository for AWS networking, compute, database, and deployment prerequisites.

## Provisioned resources

- VPC with public/private/db subnets
- ALB and listeners
- ECS cluster and services for backend/frontend
- RDS PostgreSQL
- IAM/OIDC resources for GitHub Actions deployment
- S3 + DynamoDB Terraform state/locking resources

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
└── Makefile
```

## State and locking model

Each environment uses isolated remote state and lock table:

- `dev`: `mypythonproject1-tfstate-dev` + `mypythonproject1-terraform-lock-dev`
- `staging`: `mypythonproject1-tfstate-staging` + `mypythonproject1-terraform-lock-staging`
- `prod`: `mypythonproject1-tfstate-prod` + `mypythonproject1-terraform-lock-prod`

`backend.hcl` files are rendered during CI and for local use contain:

```hcl
bucket         = "<env-state-bucket>"
key            = "<env>/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "mypythonproject1-terraform-lock-<env>"
encrypt        = true
```

## Bootstrap (per AWS account)

Bootstrap creates shared foundation resources (state buckets, lock tables, OIDC role/provider, ECR repos).

Run from repo root:

```bash
make bootstrap-init
make bootstrap-plan
make bootstrap-apply
```

Bootstrap variables are in `bootstrap/env/bootstrap.tfvars`.

## CI/CD flow

Main workflow: `.github/workflows/terraform.yml`

### PR opened to `main`

Promotion-style validation plans run in order:

1. `plan-dev`
2. `plan-staging`
3. `plan-prod`

Plan checks include:

- `terraform fmt -check`
- `terraform validate`
- `tflint`
- `tfsec`
- `terraform plan`

### After PR merge (`push` to `main`)

Promotion applies run in order:

1. `apply-dev`
2. `apply-staging` (after `apply-dev`)
3. `apply-prod` (after `apply-staging`)

Approval gates are controlled by GitHub Environments:

- `staging` environment approval gates `apply-staging`
- `production` environment approval gates `apply-prod`

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
- `SLACK_WEBHOOK_URL` (optional)
- `TEAMS_WEBHOOK_URL` (optional)

Create GitHub Environments:

- `dev`
- `staging`
- `production`

Configure required reviewers on `staging` and `production` for controlled promotion.

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
