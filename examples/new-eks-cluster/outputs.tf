# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# TFE URLs
#------------------------------------------------------------------------------
output "tfe_url" {
  value = module.tfe.tfe_url
}

#------------------------------------------------------------------------------
# IAM
#------------------------------------------------------------------------------
output "tfe_irsa_role_arn" {
  value = module.tfe.tfe_irsa_role_arn
}

output "aws_lb_controller_irsa_role_arn" {
  value = module.tfe.aws_lb_controller_irsa_role_arn
}

#------------------------------------------------------------------------------
# EKS
#------------------------------------------------------------------------------
output "tfe_eks_cluster_name" {
  value = module.tfe.eks_cluster_name
}

output "tfe_lb_security_group_id" {
  value = module.tfe.tfe_lb_security_group_id
}

#------------------------------------------------------------------------------
# Database
#------------------------------------------------------------------------------
output "rds_aurora_global_cluster_id" {
  value = module.tfe.rds_aurora_global_cluster_id
}

output "rds_aurora_cluster_arn" {
  value = module.tfe.rds_aurora_cluster_arn
}

output "tfe_database_password_base64" {
  value     = module.tfe.tfe_database_password_base64
  sensitive = true
}

#------------------------------------------------------------------------------
# Object storage
#------------------------------------------------------------------------------
output "tfe_s3_bucket_name" {
  value = module.tfe.s3_bucket_name
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
output "tfe_redis_password_base64" {
  value     = module.tfe.tfe_redis_password_base64
  sensitive = true
}