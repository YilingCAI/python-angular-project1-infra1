environment  = "prod"
project_name = "mypythonproject1-prod"
aws_region   = "us-east-1"

# Networking
vpc_cidr              = "10.2.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs   = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs  = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
database_subnet_cidrs = ["10.2.20.0/24", "10.2.21.0/24", "10.2.22.0/24"]
app_port              = 8000

# RDS
db_name                  = "gamedb"
db_username              = "postgres"
db_engine_version        = "17.6"
db_instance_class        = "db.t3.medium"
db_allocated_storage     = 100
db_max_allocated_storage = 500
backup_retention_days    = 30
multi_az                 = true
log_retention_days       = 30

# ECS
ecr_repository_url         = "381492246543.dkr.ecr.us-east-1.amazonaws.com/mypythonproject1/backend"
frontend_ecr_repository_url = "381492246543.dkr.ecr.us-east-1.amazonaws.com/mypythonproject1/frontend"
image_tag                 = "latest"
frontend_image_tag        = "latest"
task_cpu                  = "1024"
task_memory               = "2048"
desired_count             = 3
frontend_desired_count    = 3
min_capacity              = 3
max_capacity              = 10
target_cpu_utilization    = 60
target_memory_utilization = 70

# ALB & Security
health_check_path = "/health"
certificate_arn   = "" # REQUIRED: Add your ACM certificate ARN here for production

# JWT (provide during terraform apply)
# jwt_secret_key = "your-secret-key-here"

# Debug
debug = false
