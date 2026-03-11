environment  = "staging"
project_name = "mypythonproject1-staging"
aws_region   = "us-east-1"

# Networking
vpc_cidr              = "10.1.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs  = ["10.1.10.0/24", "10.1.11.0/24"]
database_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24"]
app_port              = 8000

# RDS
db_name                  = "gamedb"
db_username              = "postgres"
db_engine_version        = "17.6"
db_instance_class        = "db.t3.small"
db_allocated_storage     = 50
db_max_allocated_storage = 200
backup_retention_days    = 15
multi_az                 = true
log_retention_days       = 7

# ECS
ecr_repository_url          = "769254791061.dkr.ecr.us-east-1.amazonaws.com/mypythonproject1/backend"
frontend_ecr_repository_url = "769254791061.dkr.ecr.us-east-1.amazonaws.com/mypythonproject1/frontend"
image_tag                   = "staging"
frontend_image_tag          = "staging"
task_cpu                    = "512"
task_memory                 = "1024"
desired_count               = 2
frontend_desired_count      = 2
min_capacity                = 2
max_capacity                = 5
target_cpu_utilization      = 70
target_memory_utilization   = 80

# ALB & Security
health_check_path = "/health"
certificate_arn   = "" # Add your ACM certificate ARN here

# JWT (provide during terraform apply)
# jwt_secret_key = "your-secret-key-here"

# Debug
debug = false
