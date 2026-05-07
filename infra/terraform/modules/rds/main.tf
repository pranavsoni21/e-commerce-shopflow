# ============================================================
# ShopFlow RDS Module
# Single PostgreSQL instance with 3 databases (user, product, order)
# Deployed in private subnets — never publicly accessible
# ============================================================


# ─────────────────────────────────────────────────────────────
# SUBNET GROUP
# Tells RDS which subnets it can live in.
# Must span at least 2 AZs even for single-AZ deployments —
# AWS requirement, not optional.
# ─────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "${var.tags["ProjectName"]}-rds-subnet-group"
  description = "Private subnets for ShopFlow RDS instance"
  subnet_ids  = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-rds-subnet-group"
  })
}


# ─────────────────────────────────────────────────────────────
# SECURITY GROUP
# Controls who can talk to RDS.
# Only pods inside the EKS cluster should reach port 5432 —
# nothing from the internet, nothing from public subnets.
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "rds_sg" {
  name        = "${var.tags["ProjectName"]}-rds-sg"
  description = "Allow PostgreSQL traffic from EKS nodes only"
  vpc_id      = var.vpc_id

  # Inbound: only PostgreSQL port, only from EKS node security group
  # This means even other resources inside your VPC can't reach RDS
  # unless they're EKS nodes
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  # Outbound: allow all — RDS needs to reach AWS services
  # for backups, monitoring, etc.
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-rds-sg"
  })
}


# ─────────────────────────────────────────────────────────────
# PARAMETER GROUP
# Custom PostgreSQL settings.
# Using a custom group means you can tune settings later
# without replacing the instance.
# Default group is locked and can't be modified.
# ─────────────────────────────────────────────────────────────

resource "aws_db_parameter_group" "rds_params" {
  name        = "${var.tags["ProjectName"]}-rds-params"
  family      = "postgres15"
  description = "Custom parameter group for ShopFlow PostgreSQL 15"

  # Log slow queries — anything over 1 second gets logged
  # Useful for debugging performance issues in Grafana (Phase 7)
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # Log all connections — helps with debugging auth issues
  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-rds-params"
  })
}


# ─────────────────────────────────────────────────────────────
# RDS INSTANCE
# Single PostgreSQL 15 instance in a private subnet.
# Credentials come from Vault in production — the password
# here is just the initial bootstrap value, rotated by Vault
# after first deploy.
# ─────────────────────────────────────────────────────────────

resource "aws_db_instance" "shopflow_db" {
  identifier = "${var.tags["ProjectName"]}-db"

  # Engine
  engine         = "postgres"
  engine_version = "15.5"
  instance_class = "db.t3.micro"

  # Storage
  # gp3 is newer and cheaper than gp2 for the same performance
  allocated_storage     = 20
  max_allocated_storage = 100 # autoscaling ceiling — won't exceed this
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # Credentials
  # This is the master user — each service gets its own user/password
  # via Vault dynamic secrets (Phase 6). Never use master creds in app code.
  db_name  = "shopflow" # default database, not used by services directly
  username = var.db_username
  password = var.db_password # bootstrapped here, rotated by Vault later

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false # never expose RDS to internet

  # Configuration
  parameter_group_name = aws_db_parameter_group.rds_params.name
  multi_az             = false # single-AZ for cost — set true for production
  port                 = 5432

  # Backups
  # 7 day retention — lets you restore to any point in the last week
  backup_retention_period = 7
  backup_window           = "03:00-04:00"         # 3-4am UTC, low traffic window
  maintenance_window      = "Mon:04:00-Mon:05:00" # after backup window

  # Safety
  # Prevents accidental deletion via terraform destroy
  # Set to false only when you intentionally want to destroy
  deletion_protection = false # keep false for dev, set true for production
  skip_final_snapshot = true  # set false for production to keep a final backup

  # Performance Insights — free tier available, useful for debugging
  performance_insights_enabled = true

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-db"
  })
}


# ─────────────────────────────────────────────────────────────
# PER-SERVICE DATABASES
# Each service gets its own database inside the same instance.
# Services are completely isolated at the database level —
# user-svc cannot accidentally query productdb.
#
# These are created AFTER the RDS instance is ready.
# They run as a null_resource using psql — no extra tools needed.
# ─────────────────────────────────────────────────────────────

resource "null_resource" "create_databases" {
  # Re-run if the RDS instance is replaced
  triggers = {
    rds_instance_id = aws_db_instance.shopflow_db.id
  }

  provisioner "local-exec" {
    # Uses the psql client on the machine running terraform apply
    # In CI/CD this runs from GitHub Actions runner (has psql installed)
    command = <<-EOT
      PGPASSWORD=${var.db_password} psql \
        -h ${aws_db_instance.shopflow_db.address} \
        -U ${var.db_username} \
        -d shopflow \
        -c "CREATE DATABASE userdb;" \
        -c "CREATE DATABASE productdb;" \
        -c "CREATE DATABASE orderdb;" || true
    EOT
    # || true means if databases already exist, don't fail terraform apply
  }

  depends_on = [aws_db_instance.shopflow_db]
}
