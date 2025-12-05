# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Redis password
#------------------------------------------------------------------------------
data "aws_secretsmanager_secret_version" "tfe_redis_password" {
  secret_id     = var.tfe_redis_password_secret_arn
  version_stage = "AWSCURRENT"
}

#------------------------------------------------------------------------------
# Redis (ElastiCache) subnet group
#------------------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "tfe" {
  name       = "${var.friendly_name_prefix}-tfe-redis-subnet-group"
  subnet_ids = var.redis_subnet_ids
}

#------------------------------------------------------------------------------
# Redis (ElastiCache) cluster
#------------------------------------------------------------------------------
resource "aws_elasticache_replication_group" "redis_cluster" {
  engine                     = "redis"
  replication_group_id       = "${var.friendly_name_prefix}-tfe-redis-cluster"
  description                = "External Redis cluster for TFE Active/Active operational mode."
  engine_version             = var.redis_engine_version
  port                       = var.redis_port
  parameter_group_name       = var.redis_parameter_group_name
  node_type                  = var.redis_node_type
  num_cache_clusters         = length(var.redis_subnet_ids) # dictates number of Redis nodes (primary and replicas)
  multi_az_enabled           = var.redis_multi_az_enabled && length(var.redis_subnet_ids) > 1 ? true : false
  automatic_failover_enabled = var.redis_multi_az_enabled && length(var.redis_subnet_ids) > 1 ? true : false
  subnet_group_name          = aws_elasticache_subnet_group.tfe.name
  security_group_ids         = [aws_security_group.redis_allow_ingress.id]
  at_rest_encryption_enabled = var.redis_at_rest_encryption_enabled
  kms_key_id                 = var.redis_at_rest_encryption_enabled && var.redis_kms_key_arn != null ? var.redis_kms_key_arn : null
  transit_encryption_enabled = var.redis_transit_encryption_enabled
  auth_token                 = var.tfe_redis_password_secret_arn != null ? data.aws_secretsmanager_secret_version.tfe_redis_password.secret_string : null
  snapshot_retention_limit   = 0
  apply_immediately          = var.redis_apply_immediately
  auto_minor_version_upgrade = var.redis_auto_minor_version_upgrade

  tags = merge({ "Name" = "${var.friendly_name_prefix}-tfe-redis" }, var.common_tags)
}

#------------------------------------------------------------------------------
# Security group
#------------------------------------------------------------------------------
resource "aws_security_group" "redis_allow_ingress" {
  name   = "${var.friendly_name_prefix}-tfe-redis-allow-ingress"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.friendly_name_prefix}-tfe-redis-allow-ingress" }, var.common_tags)
}

resource "aws_security_group_rule" "redis_allow_ingress_from_nodegroup" {
  count = length(aws_security_group.tfe_eks_nodegroup_allow) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
  description              = "Allow TCP/6379 (Redis) inbound to Redis cluster from TFE EKS node group."

  security_group_id = aws_security_group.redis_allow_ingress.id
}

resource "aws_security_group_rule" "redis_allow_ingress_from_sg" {
  count = var.sg_allow_ingress_to_redis != null ? 1 : 0

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.sg_allow_ingress_to_redis
  description              = "Allow TCP/6379 (Redis) inbound to Redis cluster from specified security group ID."

  security_group_id = aws_security_group.redis_allow_ingress.id
}

resource "aws_security_group_rule" "redis_allow_ingress_from_cidr" {
  count = var.cidr_allow_ingress_to_redis != null ? 1 : 0

  type        = "ingress"
  from_port   = 6379
  to_port     = 6379
  protocol    = "tcp"
  cidr_blocks = var.cidr_allow_ingress_to_redis
  description = "Allow TCP/6379 (Redis) inbound to Redis cluster from specified CIDR ranges."

  security_group_id = aws_security_group.redis_allow_ingress.id
}
