##############################################################################
# Latest Amazon Linux 2023 AMI, looked up rather than hardcoded
##############################################################################
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

##############################################################################
# Generated secrets. special = false keeps them URL-safe so they can be
# embedded in a MongoDB connection string without percent-encoding.
##############################################################################
resource "random_password" "mongo" {
  length  = 32
  special = false
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}

##############################################################################
# Parameter Store. The application reads these at boot using its IAM role,
# which is why no secret ever appears in git or in a pipeline variable.
##############################################################################
resource "aws_ssm_parameter" "mongo_password" {
  name  = "/${var.project_name}/mongo/password"
  type  = "SecureString"
  value = random_password.mongo.result
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${var.project_name}/app/jwt_secret"
  description = "Shared across both backend instances so sessions survive failover"
  type        = "SecureString"
  value       = random_password.jwt.result
}

resource "aws_ssm_parameter" "mongo_uri" {
  name  = "/${var.project_name}/app/mongo_uri"
  type  = "SecureString"
  value = "mongodb://${var.mongo_username}:${random_password.mongo.result}@${aws_instance.mongo.private_ip}:27017/?replicaSet=rs0&authSource=admin"
}

resource "aws_ssm_parameter" "redis_addr" {
  name  = "/${var.project_name}/app/redis_addr"
  type  = "String"
  value = "${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/app/db_name"
  type  = "String"
  value = var.mongo_db_name
}

##############################################################################
# IAM role for the MongoDB host. Grants Session Manager access (so we never
# need SSH or a bastion) and permission to read its own password.
##############################################################################
resource "aws_iam_role" "mongo" {
  name = "${var.project_name}-mongo-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mongo_ssm_core" {
  role       = aws_iam_role.mongo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "mongo_read_secret" {
  name = "${var.project_name}-mongo-read-secret"
  role = aws_iam_role.mongo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = aws_ssm_parameter.mongo_password.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = data.aws_kms_alias.ssm.target_key_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongo" {
  name = "${var.project_name}-mongo-profile"
  role = aws_iam_role.mongo.name
}

##############################################################################
# The MongoDB host itself. Single-node replica set, because the application
# uses transactions and MongoDB refuses those on a standalone server.
##############################################################################
resource "aws_instance" "mongo" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.mongo_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.mongo_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.mongo.name

  user_data                   = templatefile("${path.module}/templates/mongo-user-data.sh.tftpl", {
    region               = var.aws_region
    mongo_user           = var.mongo_username
    mongo_password_param = aws_ssm_parameter.mongo_password.name
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = "${var.project_name}-mongodb"
    Role = "database"
  }
}

##############################################################################
# ElastiCache Redis. Two nodes across two AZs with automatic failover.
##############################################################################
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-redis"
  description          = "Cache for the Much-to-Do backend"

  engine               = "redis"
  engine_version       = "7.1"
  parameter_group_name = "default.redis7"
  node_type            = var.redis_node_type
  port                 = 6379

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_security_group_id]

  # The Go redis client in this application connects without TLS.
  transit_encryption_enabled = false
  at_rest_encryption_enabled = true

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-redis"
  }
}
