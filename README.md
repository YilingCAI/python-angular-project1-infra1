# mypythonproject1-infra

Professional infrastructure repository for mypythonproject1 using Terraform on AWS ECS Fargate.

## Project Overview

This repository provisions the core AWS platform for the application, including networking, load balancing, compute services, database, and IAM controls for CI/CD.

It is designed with environment isolation and promotion flow across dev, staging, and production.

## Architecture Flow

ALB -> ECS services (frontend and backend) -> RDS PostgreSQL

## Architecture Diagram

```text
Internet Users
	|
	v
+-------------------------------+
| Application Load Balancer     |
|  - Listeners: 80 / 443        |
|  - Host/path routing           |
+---------------+---------------+
		    |
		    v
+-----------------------------------------------+
| ECS Cluster (Fargate)                         |
|                                               |
|  +---------------------+  +-----------------+ |
|  | Frontend Service    |  | Backend Service | |
|  | Angular + Nginx     |  | Python API      | |
|  +---------------------+  +-----------------+ |
+-------------------------------+---------------+
					  |
					  v
				+------------------+
				| AWS RDS Postgres |
				+------------------+
```

## Provisioned Components

- VPC and subnet topology (public, private, database)
- Application Load Balancer and listener rules
- ECS services for backend and frontend
- RDS PostgreSQL and related security resources
- IAM roles and policies for runtime and CI/CD
- Monitoring resources and shared platform controls

## Terraform Structure

Infrastructure is split into reusable modules and environment roots.

### Modules

- modules/vpc: VPC, subnets, routing, internet/NAT components
- modules/alb: ALB, listeners, target groups, and ingress routing
- modules/ecs-service: ECS task/service and autoscaling definitions
- modules/rds: PostgreSQL database and data-plane security resources
- modules/iam: IAM roles and policies for workload and pipeline access
- modules/monitoring: telemetry, logging, and operational visibility resources

### Environment roots

Each environment root under environments/dev, environments/staging, and environments/prod contains:

- main.tf
- variables.tf
- outputs.tf
- providers.tf
- backend.hcl
- terraform.tfvars

## Repository Structure

| Path | Purpose |
|---|---|
| environments/dev/ | Development Terraform root |
| environments/staging/ | Staging Terraform root |
| environments/prod/ | Production Terraform root |
| modules/vpc/ | Network module |
| modules/alb/ | Ingress and load balancing module |
| modules/ecs-service/ | ECS service module |
| modules/rds/ | Database module |
| modules/iam/ | IAM and access controls |
| modules/monitoring/ | Monitoring and observability resources |
| .github/workflows/ | Plan, apply, drift, and utility workflows |

## Environment Model

Each environment has a dedicated Terraform root with its own:

- backend.hcl
- terraform.tfvars
- provider and variable settings

This keeps state, parameters, and promotion behavior isolated per environment.

## Deployment Steps

```bash
# Initialize Terraform
terraform -chdir=environments/staging init

# Plan
terraform -chdir=environments/staging plan

# Apply
terraform -chdir=environments/staging apply
```

## CI/CD Strategy

- Pull requests run speculative plan and quality checks.
- Main branch promotion follows ordered plan/apply across environments.
- Drift detection runs on schedule to identify out-of-band changes.
- Manual approval gates are expected for staging and production applies.

## Security Groups Model

- ALB security group:
	- Inbound: 80/443 from internet
	- Outbound: app traffic to ECS service security groups
- ECS service security groups:
	- Inbound: service ports only from ALB security group
	- Outbound: restricted egress to required dependencies
- RDS security group:
	- Inbound: PostgreSQL port only from backend ECS security group

## Scaling Strategy

- Horizontal scaling is handled at service level by adjusting desired task counts.
- ALB distributes requests across healthy ECS tasks.
- Independent scaling for frontend and backend supports workload-specific tuning.
- Environment-specific task sizing balances cost and reliability per stage.

## Local Validation

```bash
terraform -chdir=environments/dev init -backend=false
terraform -chdir=environments/dev validate

terraform -chdir=environments/staging init -backend=false
terraform -chdir=environments/staging validate

terraform -chdir=environments/prod init -backend=false
terraform -chdir=environments/prod validate
```

## Tech Stack

- Terraform
- AWS ECS Fargate
- AWS Application Load Balancer
- AWS RDS PostgreSQL
- AWS IAM
- GitHub Actions

## Security and Operations Notes

- Use OIDC-based role assumption in CI/CD instead of long-lived credentials.
- Keep backend state encrypted and protected with locking.
- Protect production workflows with GitHub Environment approvals.

## Future Improvements

- Add blue/green deployment options for ECS services.
- Add policy-as-code and OPA checks in plan stage.
- Add cost guardrails and budget-aware deployment policies.
- Add expanded SLO alerting and incident automation.
