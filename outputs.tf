# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# TFE URLs
#------------------------------------------------------------------------------
output "tfe_url" {
  value       = "https://${var.tfe_fqdn}"
  description = "URL to access TFE application based on value of `tfe_fqdn` input."
}

#------------------------------------------------------------------------------
# IAM
#------------------------------------------------------------------------------
output "tfe_irsa_role_arn" {
  value       = try(aws_iam_role.tfe_irsa[0].arn, null)
  description = "ARN of IAM role for TFE EKS IRSA."
}

output "aws_lb_controller_irsa_role_arn" {
  value       = try(aws_iam_role.aws_lb_controller_irsa[0].arn, null)
  description = "ARN of IAM role for AWS Load Balancer Controller IRSA."
}

#------------------------------------------------------------------------------
# EKS
#------------------------------------------------------------------------------
output "eks_cluster_name" {
  value       = try(aws_eks_cluster.tfe[0].name, null)
  description = "Name of TFE EKS cluster."
}

output "tfe_lb_security_group_id" {
  value       = try(aws_security_group.tfe_lb_allow[0].id, null)
  description = "ID of security group for TFE load balancer."
}

output "eks_cluster_security_group_id" {
  value       = try(aws_eks_cluster.tfe[0].vpc_config[0].cluster_security_group_id, null)
  description = "ID of the default cluster security group created by EKS."
}

#------------------------------------------------------------------------------
# Database
#------------------------------------------------------------------------------
output "tfe_database_host" {
  value       = "${aws_rds_cluster.tfe.endpoint}:5432"
  description = "PostgreSQL server endpoint in the format that TFE will connect to."
}

output "rds_aurora_global_cluster_id" {
  value       = try(aws_rds_global_cluster.tfe[0].id, null)
  description = "RDS Aurora global database cluster identifier."
}

output "rds_aurora_cluster_arn" {
  value       = aws_rds_cluster.tfe.arn
  description = "ARN of RDS Aurora database cluster."
  depends_on  = [aws_rds_cluster_instance.tfe]
}

output "rds_aurora_cluster_members" {
  value       = aws_rds_cluster.tfe.cluster_members
  description = "List of instances that are part of this RDS Aurora database cluster."
  depends_on  = [aws_rds_cluster_instance.tfe]
}

output "rds_aurora_cluster_endpoint" {
  value       = aws_rds_cluster.tfe.endpoint
  description = "RDS Aurora database cluster endpoint."
}

output "tfe_database_password" {
  value       = data.aws_secretsmanager_secret_version.tfe_database_password.secret_string
  description = "TFE PostgreSQL database password."
  sensitive   = true
}

output "tfe_database_password_base64" {
  value       = base64encode(data.aws_secretsmanager_secret_version.tfe_database_password.secret_string)
  description = "Base64-encoded TFE PostgreSQL database password."
  sensitive   = true
}

#------------------------------------------------------------------------------
# Object storage
#------------------------------------------------------------------------------
output "s3_bucket_name" {
  value       = aws_s3_bucket.tfe.id
  description = "Name of TFE S3 bucket."
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.tfe.arn
  description = "ARN of TFE S3 bucket."
}

output "s3_crr_iam_role_arn" {
  value       = aws_iam_role.s3_crr.*.arn
  description = "ARN of S3 cross-region replication IAM role."
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
output "elasticache_replication_group_arn" {
  value       = aws_elasticache_replication_group.redis_cluster.arn
  description = "ARN of ElastiCache Replication Group (Redis) cluster."
}

output "elasticache_replication_group_id" {
  value       = aws_elasticache_replication_group.redis_cluster.id
  description = "ID of ElastiCache Replication Group (Redis) cluster."
}

output "elasticache_replication_group_primary_endpoint_address" {
  value       = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
  description = "Primary endpoint address of ElastiCache Replication Group (Redis) cluster."
}

output "tfe_redis_password" {
  value       = data.aws_secretsmanager_secret_version.tfe_redis_password.secret_string
  description = "TFE Redis password."
  sensitive   = true
}

output "tfe_redis_password_base64" {
  value       = base64encode(data.aws_secretsmanager_secret_version.tfe_redis_password.secret_string)
  description = "Base64-encoded TFE Redis password."
  sensitive   = true
}
