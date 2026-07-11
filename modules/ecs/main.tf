locals {
  tags = merge(var.tags, { ManagedBy = "terraform" })
}

# ---------------------------------------------------------------------------
# Log group for ECS Exec (interactive `aws ecs execute-command` sessions)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "exec" {
  name              = "/ecs/${var.name}/exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(local.tags, { Name = "${var.name}-exec" })
}

# ---------------------------------------------------------------------------
# ECS cluster (Fargate) with Container Insights and audited Exec
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  configuration {
    execute_command_configuration {
      # Send every ECS Exec session to CloudWatch for audit.
      logging    = "OVERRIDE"
      kms_key_id = var.kms_key_arn

      log_configuration {
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec.name
        cloud_watch_encryption_enabled = var.kms_key_arn != null
      }
    }
  }

  tags = merge(local.tags, { Name = var.name })
}

# ---------------------------------------------------------------------------
# Capacity providers: Fargate on-demand (baseline) + optional Spot
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = var.enable_fargate_spot ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = var.fargate_base
    weight            = var.fargate_weight
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = var.enable_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = var.fargate_spot_weight
    }
  }
}

# ---------------------------------------------------------------------------
# IAM roles that Fargate services attach to
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: lets the agent pull images from ECR and ship logs.
resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(local.tags, { Name = "${var.name}-execution" })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: identity the application containers run as. Empty by default —
# each service attaches the policies it actually needs.
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(local.tags, { Name = "${var.name}-task" })
}

# ---------------------------------------------------------------------------
# Base security group for Fargate tasks in this cluster
# ---------------------------------------------------------------------------
# Tasks need outbound to reach ECR, CloudWatch and app dependencies via the
# VPC's NAT. Ingress is intentionally empty; services add rules (e.g. from an
# ALB) as needed.
#trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "Base security group for ${var.name} Fargate tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.name}-tasks" })
}
