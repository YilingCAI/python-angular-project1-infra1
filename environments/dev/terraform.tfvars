environment  = "dev"
project_name = "mypythonproject1-dev"
aws_region   = "us-east-1"

# Networking
vpc_cidr              = "10.0.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
app_port              = 8000

# RDS
db_name                  = "gamedb"
db_username              = "postgres"
db_engine_version        = "17.6"
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 100
backup_retention_days    = 7
multi_az                 = false
log_retention_days       = 3

# ECS
ecr_repository_url          = "388252587928.dkr.ecr.us-east-1.amazonaws.com/mypythonproject1/backend"
frontend_ecr_repository_url = "388252587928.dkr.ecr.us-east-1.amazonaws.com/mypythonproject1/frontend"
image_tag                   = "dev"
frontend_image_tag          = "dev"
task_cpu                    = "256"
task_memory                 = "512"
desired_count               = 1
frontend_desired_count      = 1
min_capacity                = 1
max_capacity                = 3
target_cpu_utilization      = 70
target_memory_utilization   = 80

# ALB & Security
health_check_path = "/health"
certificate_arn   = ""

# Debug
debug = true

# Monitoring
alert_email          = "" # Add your email to receive CloudWatch alarm notifications
ecs_cpu_threshold    = 80
ecs_memory_threshold = 85
rds_cpu_threshold    = 80
