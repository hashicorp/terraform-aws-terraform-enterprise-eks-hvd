# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Common
#------------------------------------------------------------------------------
variable "friendly_name_prefix" {
  type        = string
  description = "Friendly name prefix used for uniquely naming all AWS resources for this deployment. Most commonly set to either an environment (e.g. 'sandbox', 'prod') a team name, or a project name."

  validation {
    condition     = !strcontains(lower(var.friendly_name_prefix), "tfe")
    error_message = "Value must not contain the substring 'tfe' to avoid redundancy in resource naming."
  }
}

variable "common_tags" {
  type        = map(string)
  description = "Map of common tags for all taggable AWS resources."
  default     = {}
}

variable "force_destroy_s3_bucket" {
  type        = bool
  description = "ability to detroy the s3 bucket if needed"
  default     = false
}

variable "is_secondary_region" {
  type        = bool
  description = "Boolean indicating whether this TFE deployment is in the 'primary' region or 'secondary' region."
  default     = false
}

#------------------------------------------------------------------------------
# TFE configuration settings
#------------------------------------------------------------------------------
variable "tfe_fqdn" {
  type        = string
  description = "Fully qualified domain name (FQDN) of TFE instance. This name should eventually resolve to the TFE load balancer DNS name or IP address and will be what clients use to access TFE."
}

variable "tfe_http_port" {
  type        = number
  description = "HTTP port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 8080
}

variable "tfe_https_port" {
  type        = number
  description = "HTTPS port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 8443
}

variable "tfe_metrics_http_port" {
  type        = number
  description = "HTTP port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 9090
}

variable "tfe_metrics_https_port" {
  type        = number
  description = "HTTPS port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 9091
}

variable "create_helm_overrides_file" {
  type        = bool
  description = "Boolean to generate a YAML file from template with Helm overrides values for TFE deployment."
  default     = true
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------
variable "vpc_id" {
  type        = string
  description = "ID of VPC where TFE will be deployed."
}

variable "eks_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to use for EKS cluster."
  default     = null
}

variable "rds_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to use for RDS database subnet group."
}

variable "redis_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to use for Redis cluster subnet group."
}

variable "create_tfe_lb_security_group" {
  type        = bool
  description = "Boolean to create security group for TFE load balancer (load balancer is managed by Helm/K8s)."
  default     = true
}

variable "cidr_allow_ingress_tfe_443" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/443 inbound to TFE load balancer (load balancer is managed by Helm/K8s)."
  default     = []
}

variable "cidr_allow_ingress_tfe_metrics_http" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/9090 or port specified in `tfe_metrics_http_port` (TFE HTTP metrics endpoint) inbound to TFE node group instances."
  default     = null

  validation {
    condition     = var.cidr_allow_ingress_tfe_metrics_http != null ? length(var.cidr_allow_ingress_tfe_metrics_http) > 0 : true
    error_message = "If not `null`, value must contain at least one valid CIDR range in the list."
  }
}

variable "cidr_allow_ingress_tfe_metrics_https" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/9091 or port specified in `tfe_metrics_https_port` (TFE HTTPS metrics endpoint) inbound to TFE node group instances."
  default     = null

  validation {
    condition     = var.cidr_allow_ingress_tfe_metrics_https != null ? length(var.cidr_allow_ingress_tfe_metrics_https) > 0 : true
    error_message = "If not `null`, value must contain at least one valid CIDR range in the list."
  }
}

variable "cidr_allow_egress_from_tfe_lb" {
  type        = list(string)
  description = "List of CIDR ranges to allow all outbound traffic from TFE load balancer. Only set this to your TFE pod CIDR ranges when an EKS cluster already exists outside of this module."
  default     = null

  validation {
    condition     = !var.create_tfe_lb_security_group ? var.cidr_allow_egress_from_tfe_lb == null : true
    error_message = "Value must be `null` when `create_tfe_lb_security_group` is `false`."
  }

  validation {
    condition     = var.create_eks_cluster ? var.cidr_allow_egress_from_tfe_lb == null : true
    error_message = "Value must `null` when `create_eks_cluster` is `true`."
  }
}

variable "sg_allow_egress_from_tfe_lb" {
  type        = string
  description = "Security group ID of EKS node group to allow all egress traffic from TFE load balancer. Only set this to your TFE pod security group ID when an EKS cluster already exists outside of this module."
  default     = null

  validation {
    condition     = !var.create_tfe_lb_security_group ? var.sg_allow_egress_from_tfe_lb == null : true
    error_message = "Value must be `null` when `create_tfe_lb_security_group` is `false`."
  }

  validation {
    condition     = var.create_eks_cluster ? var.sg_allow_egress_from_tfe_lb == null : true
    error_message = "Value must `null` when `create_eks_cluster` is `true`."
  }
}

#------------------------------------------------------------------------------
# IAM
#------------------------------------------------------------------------------
variable "create_eks_oidc_provider" {
  type        = bool
  description = "Boolean to create OIDC provider used to configure AWS IRSA."
  default     = false
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "ARN of existing OIDC provider for EKS cluster. Required when `create_eks_oidc_provider` is `false`."
  default     = null

  validation {
    condition     = var.create_tfe_eks_irsa && !var.create_eks_oidc_provider ? var.eks_oidc_provider_arn != null : true
    error_message = "Value of existing OIDC provider ARN is required when `create_tfe_eks_irsa` is `true` and `create_eks_oidc_provider` is `false`."
  }
}

variable "eks_oidc_provider_url" {
  type        = string
  description = "URL of existing OIDC provider for EKS cluster. Required when `create_eks_oidc_provider` is `false`."
  default     = null

  validation {
    condition     = var.create_eks_oidc_provider && !var.create_eks_cluster ? var.eks_oidc_provider_url != null : true
    error_message = "Value of existing OIDC provider URL is required when `create_eks_oidc_provider` is `false`."
  }
}

variable "create_tfe_eks_irsa" {
  type        = bool
  description = "Boolean to create TFE IAM role and policies to enable TFE EKS IAM role for service accounts (IRSA)."
  default     = false
  validation {
    condition     = !(var.create_tfe_eks_irsa && var.create_tfe_eks_pod_identity)
    error_message = "Only one of create_tfe_eks_pod_identity or create_tfe_eks_irsa is allowed."
  }
}

variable "create_tfe_eks_pod_identity" {
  type        = bool
  description = "Boolean to create TFE IAM role and policies with the EKS addon to enable TFE EKS IAM role using Pod Identity."
  default     = false

  validation {
    condition     = var.create_tfe_eks_pod_identity ? var.create_eks_cluster || (var.existing_eks_cluster_name != null && var.existing_eks_cluster_name != "") : true
    error_message = "Pod Identity for TFE requires either creating a new EKS cluster or providing an existing EKS cluster name."
  }
}

variable "existing_eks_cluster_name" {
  type        = string
  description = "Name of existing EKS cluster, which will receive Pod Identity addon. Required when `create_eks_cluster` is `false` and `create_tfe_eks_pod_identity` is true."
  default     = null
}

variable "eks_pod_identity_addon_version" {
  type        = string
  description = "The version of the EKS Pod Identity Agent to use. Defaults to latest."
  default     = null
}

variable "tfe_kube_namespace" {
  type        = string
  description = "Name of Kubernetes namespace for TFE service account (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)."
  default     = "tfe"
}

variable "tfe_kube_svc_account" {
  type        = string
  description = "Name of Kubernetes service account for TFE (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)."
  default     = "tfe"
}

variable "create_aws_lb_controller_irsa" {
  type        = bool
  description = "Boolean to create AWS Load Balancer Controller IAM role and policies to enable EKS IAM role for service accounts (IRSA)."
  default     = false

  validation {
    condition     = !(var.create_aws_lb_controller_irsa && var.create_aws_lb_controller_pod_identity)
    error_message = "Only one of create_aws_lb_controller_pod_identity or create_aws_lb_controller_irsa is allowed."
  }
}

variable "create_aws_lb_controller_pod_identity" {
  type        = bool
  description = "Boolean to create AWS Load Balancer Controller IAM role and policies with the EKS addon to enable AWS LB Controller EKS IAM role using Pod Identity."
  default     = false

  validation {
    condition     = var.create_aws_lb_controller_pod_identity ? var.create_eks_cluster || (var.existing_eks_cluster_name != null && var.existing_eks_cluster_name != "") : true
    error_message = "Pod Identity for AWS LB Controller requires either creating a new EKS cluster or providing an existing EKS cluster name."
  }
}

variable "aws_lb_controller_kube_namespace" {
  type        = string
  description = "Name of Kubernetes namespace for AWS Load Balancer Controller service account (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)."
  default     = "kube-system"
}

variable "aws_lb_controller_kube_svc_account" {
  type        = string
  description = "Name of Kubernetes service account for AWS Load Balancer Controller (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)."
  default     = "aws-load-balancer-controller"
}

variable "role_permissions_boundary" {
  type        = string
  description = "ARN of the IAM role permissions boundary to be attached."
  default     = ""
}

#------------------------------------------------------------------------------
# EKS
#------------------------------------------------------------------------------
variable "create_eks_cluster" {
  type        = bool
  description = "Boolean to create new EKS cluster for TFE."
  default     = false
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of created EKS cluster. Will be prefixed by `var.friendly_name_prefix`"
  default     = "tfe-eks-cluster"
}

variable "eks_cluster_authentication_mode" {
  type        = string
  description = "Authentication mode for access config of EKS cluster."
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API_AND_CONFIG_MAP", "CONFIG_MAP", "API"], var.eks_cluster_authentication_mode)
    error_message = "Supported values are `API_AND_CONFIG_MAP`, `CONFIG_MAP`, or `API`."
  }
}

variable "eks_cluster_endpoint_public_access" {
  type        = bool
  description = "Boolean to enable public access to the EKS cluster endpoint."
  default     = false
}

variable "eks_cluster_public_access_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks to allow public access to the EKS cluster endpoint. Only valid when `eks_cluster_endpoint_public_access` is `true`."
  default     = null

  validation {
    condition     = var.eks_cluster_endpoint_public_access ? var.eks_cluster_public_access_cidrs != null : true
    error_message = "Value must be set when `eks_cluster_endpoint_public_access` is `true`."
  }
}

variable "eks_cluster_service_ipv4_cidr" {
  type        = string
  description = "CIDR block for the EKS cluster Kubernetes service network. Must be a valid /16 CIDR block. EKS will auto-assign from either 10.100.0.0/16 or 172.20.0.0/16 CIDR blocks when `null`."
  default     = null

  validation {
    condition     = var.eks_cluster_service_ipv4_cidr != null ? can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/16$", var.eks_cluster_service_ipv4_cidr)) : true
    error_message = "Value must be a valid /16 CIDR block. Example: 10.100.0.0/16."
  }
}

variable "eks_nodegroup_name" {
  type        = string
  description = "Name of EKS node group."
  default     = "tfe-eks-nodegroup"
}

variable "eks_nodegroup_instance_type" {
  type        = string
  description = "Instance type for worker nodes within EKS node group."
  default     = "m7i.xlarge"
}

variable "eks_nodegroup_ami_type" {
  type        = string
  description = "Type of AMI to use for EKS node group. Must be set to `CUSTOM` when `eks_nodegroup_ami_id` is not `null`."
  default     = "AL2023_x86_64_STANDARD"
}

variable "eks_nodegroup_ami_id" {
  type        = string
  description = "ID of AMI to use for EKS node group. Required when `eks_nodegroup_ami_type` is `CUSTOM`."
  default     = null

  validation {
    condition     = var.eks_nodegroup_ami_id != null ? var.eks_nodegroup_ami_type == "CUSTOM" : true
    error_message = "Value must be set when `eks_nodegroup_ami_type` is `CUSTOM`."
  }
}

variable "eks_nodegroup_scaling_config" {
  type        = map(number)
  description = "Scaling configuration for EKS node group."
  default = {
    desired_size = 3
    max_size     = 3
    min_size     = 2
  }
}

variable "eks_nodegroup_ebs_kms_key_arn" {
  type        = string
  description = "ARN of KMS customer managed key (CMK) to encrypt EKS node group EBS volumes."
  default     = null
}

#------------------------------------------------------------------------------
# RDS Aurora PostgreSQL (database)
#------------------------------------------------------------------------------
variable "tfe_database_password_secret_arn" {
  type        = string
  description = "ARN of AWS Secrets Manager secret for the TFE RDS Aurora (PostgreSQL) database password."
}

variable "tfe_database_name" {
  type        = string
  description = "Name of TFE database to create within RDS global cluster."
  default     = "tfe"
}

variable "rds_availability_zones" {
  type        = list(string)
  description = "List of AWS availability zones to spread Aurora database cluster instances across. Leave as `null` and RDS will automatically assign 3 availability zones."
  default     = null

  validation {
    condition     = try(length(var.rds_availability_zones) <= 3, var.rds_availability_zones == null)
    error_message = "A maximum of three availability zones can be specified."
  }
}

variable "rds_deletion_protection" {
  type        = bool
  description = "Boolean to enable deletion protection for RDS global cluster."
  default     = false
}

variable "rds_aurora_engine_version" {
  type        = number
  description = "Engine version of RDS Aurora PostgreSQL."
  default     = 16.2
}

variable "rds_force_destroy" {
  type        = bool
  description = "Boolean to enable the removal of RDS database cluster members from RDS global cluster on destroy."
  default     = false
}

variable "rds_storage_encrypted" {
  type        = bool
  description = "Boolean to encrypt RDS storage. An AWS managed key will be used when `true` unless a value is also specified for `rds_kms_key_arn`."
  default     = true
}


variable "rds_global_cluster_id" {
  type        = string
  description = "ID of RDS global cluster. Only required only when `is_secondary_region` is `true`, otherwise leave as `null`."
  default     = null

  validation {
    condition     = var.is_secondary_region ? var.rds_global_cluster_id != null : true
    error_message = "Value must be set when `is_secondary_region` is `true`."
  }

  validation {
    condition     = !var.is_secondary_region ? var.rds_global_cluster_id == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `false`."
  }
}

variable "rds_aurora_engine_mode" {
  type        = string
  description = "RDS Aurora database engine mode."
  default     = "provisioned"
}

variable "tfe_database_user" {
  type        = string
  description = "Username for TFE RDS database cluster."
  default     = "tfe"
}

variable "tfe_database_parameters" {
  type        = string
  description = "PostgreSQL server parameters for the connection URI. Used to configure the PostgreSQL connection."
  default     = "sslmode=require"
}

variable "rds_kms_key_arn" {
  type        = string
  description = "ARN of KMS customer managed key (CMK) to encrypt TFE RDS cluster."
  default     = null

  validation {
    condition     = var.rds_kms_key_arn != null ? var.rds_storage_encrypted : true
    error_message = "`rds_storage_encrypted` must be `true` when specifying a `rds_kms_key_arn`."
  }
}

variable "rds_replication_source_identifier" {
  type        = string
  description = "ARN of source RDS cluster or cluster instance if this cluster is to be created as a read replica. Only required when `is_secondary_region` is `true`, otherwise leave as `null`."
  default     = null

  validation {
    condition     = var.is_secondary_region ? var.rds_replication_source_identifier != null : true
    error_message = "Value must be set when `is_secondary_region` is `true`."
  }

  validation {
    condition     = !var.is_secondary_region ? var.rds_replication_source_identifier == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `false`."
  }
}

variable "rds_source_region" {
  type        = string
  description = "Source region for RDS cross-region replication. Only required when `is_secondary_region` is `true`, otherwise leave as `null`."
  default     = null

  validation {
    condition     = var.is_secondary_region ? var.rds_source_region != null : true
    error_message = "Value must be set when `is_secondary_region` is `true`."
  }

  validation {
    condition     = !var.is_secondary_region ? var.rds_source_region == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `false`."
  }
}

variable "rds_backup_retention_period" {
  type        = number
  description = "The number of days to retain backups for. Must be between 0 and 35. Must be greater than 0 if the database cluster is used as a source of a read replica cluster."
  default     = 35

  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35
    error_message = "Value must be between 0 and 35."
  }
}

variable "rds_preferred_backup_window" {
  type        = string
  description = "Daily time range (UTC) for RDS backup to occur. Must not overlap with `rds_preferred_maintenance_window`."
  default     = "04:00-04:30"

  validation {
    condition     = can(regex("^([01]?[0-9]|2[0-3]):[0-5][0-9]-([01]?[0-9]|2[0-3]):[0-5][0-9]$", var.rds_preferred_backup_window))
    error_message = "Value must be in the format 'HH:MM-HH:MM'."
  }
}

variable "rds_preferred_maintenance_window" {
  type        = string
  description = "Window (UTC) to perform RDS database maintenance. Must not overlap with `rds_preferred_backup_window`."
  default     = "Sun:08:00-Sun:09:00"

  validation {
    condition     = can(regex("^(Mon|Tue|Wed|Thu|Fri|Sat|Sun):([01]?[0-9]|2[0-3]):[0-5][0-9]-(Mon|Tue|Wed|Thu|Fri|Sat|Sun):([01]?[0-9]|2[0-3]):[0-5][0-9]$", var.rds_preferred_maintenance_window))
    error_message = "Value must be in the format 'Day:HH:MM-Day:HH:MM'."
  }
}

variable "rds_skip_final_snapshot" {
  type        = bool
  description = "Boolean to enable RDS to take a final database snapshot before destroying."
  default     = false
}

variable "rds_aurora_instance_class" {
  type        = string
  description = "Instance class of Aurora PostgreSQL database."
  default     = "db.r6i.xlarge"
}

variable "rds_apply_immediately" {
  type        = bool
  description = "Boolean to apply changes immediately to RDS cluster instance."
  default     = true
}

variable "rds_parameter_group_family" {
  type        = string
  description = "Family of Aurora PostgreSQL database parameter group."
  default     = "aurora-postgresql16"
}

variable "rds_aurora_replica_count" {
  type        = number
  description = "Number of replica (reader) cluster instances to create within the RDS Aurora database cluster (within the same region)."
  default     = 1
}

variable "rds_performance_insights_enabled" {
  type        = bool
  description = "Boolean to enable performance insights for RDS cluster instance(s)."
  default     = true
}

variable "rds_performance_insights_retention_period" {
  type        = number
  description = "Number of days to retain RDS performance insights data. Must be between 7 and 731."
  default     = 7
}

variable "sg_allow_ingress_to_rds" {
  type        = string
  description = "Security group ID to allow TCP/5432 (PostgreSQL) inbound to RDS cluster."
  default     = null
}

variable "cidr_allow_ingress_to_rds" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/5432 (PostgreSQL) inbound to RDS cluster."
  default     = null
}

#------------------------------------------------------------------------------
# S3 (object storage)
#------------------------------------------------------------------------------
variable "tfe_object_storage_s3_use_instance_profile" {
  type        = bool
  description = "Boolean to use instance profile for S3 bucket access. If `false`, `tfe_object_storage_s3_access_key_id` and `tfe_object_storage_s3_secret_access_key` are required."
  default     = true
}

variable "tfe_object_storage_s3_access_key_id" {
  type        = string
  description = "Access key ID for S3 bucket. Required when `tfe_object_storage_s3_use_instance_profile` is `false`."
  default     = null

  validation {
    condition     = !var.tfe_object_storage_s3_use_instance_profile ? var.tfe_object_storage_s3_access_key_id != null : true
    error_message = "Value must be set when `tfe_object_storage_s3_use_instance_profile` is `false`."
  }

  validation {
    condition     = var.tfe_object_storage_s3_use_instance_profile ? var.tfe_object_storage_s3_access_key_id == null : true
    error_message = "Value must be `null` when `tfe_object_storage_s3_use_instance_profile` is `true`."
  }
}

variable "tfe_object_storage_s3_secret_access_key" {
  type        = string
  description = "Secret access key for S3 bucket. Required when `tfe_object_storage_s3_use_instance_profile` is `false`."
  default     = null

  validation {
    condition     = !var.tfe_object_storage_s3_use_instance_profile ? var.tfe_object_storage_s3_secret_access_key != null : true
    error_message = "Value must be set when `tfe_object_storage_s3_use_instance_profile` is `false`."
  }

  validation {
    condition     = var.tfe_object_storage_s3_use_instance_profile ? var.tfe_object_storage_s3_secret_access_key == null : true
    error_message = "Value must be `null` when `tfe_object_storage_s3_use_instance_profile` is `true`."
  }
}

variable "s3_kms_key_arn" {
  type        = string
  description = "ARN of KMS customer managed key (CMK) to encrypt TFE S3 bucket with."
  default     = null
}

variable "s3_enable_bucket_replication" {
  type        = bool
  description = "Boolean to enable cross-region replication for TFE S3 bucket. Do not enable when `is_secondary_region` is `true`. An `s3_destination_bucket_arn` is also required when `true`."
  default     = false

  validation {
    condition     = var.is_secondary_region ? !var.s3_enable_bucket_replication : true
    error_message = "Cross-region replication cannot be enabled when `is_secondary_region` is `true`."
  }

  validation {
    condition     = var.s3_enable_bucket_replication ? var.s3_destination_bucket_arn != "" : true
    error_message = "When `true`, an `s3_destination_bucket_arn` is also required."
  }
}

variable "s3_destination_bucket_arn" {
  type        = string
  description = "ARN of destination S3 bucket for cross-region replication configuration. Bucket should already exist in secondary region. Required when `s3_enable_bucket_replication` is `true`."
  default     = ""
}

variable "s3_destination_bucket_kms_key_arn" {
  type        = string
  description = "ARN of KMS key of destination S3 bucket for cross-region replication configuration if it is encrypted with a customer managed key (CMK)."
  default     = null
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
variable "tfe_redis_password_secret_arn" {
  type        = string
  description = "ARN of AWS Secrets Manager secret for the TFE Redis password. Value of secret must contain from 16 to 128 alphanumeric characters or symbols (excluding @, \", and /)."
}

variable "redis_engine_version" {
  type        = string
  description = "Redis version number."
  default     = "7.1"
}

variable "redis_port" {
  type        = number
  description = "Port number the Redis nodes will accept connections on."
  default     = 6379
}

variable "redis_parameter_group_name" {
  type        = string
  description = "Name of parameter group to associate with Redis cluster."
  default     = "default.redis7"
}

variable "redis_node_type" {
  type        = string
  description = "Type (size) of Redis node from a compute, memory, and network throughput standpoint."
  default     = "cache.m5.large"
}

variable "redis_multi_az_enabled" {
  type        = bool
  description = "Boolean to create Redis nodes across multiple availability zones. If `true`, `redis_automatic_failover_enabled` must also be `true`, and more than one subnet must be specified within `redis_subnet_ids`."
  default     = true

  validation {
    condition     = var.redis_multi_az_enabled ? var.redis_automatic_failover_enabled && length(var.redis_subnet_ids) > 1 : true
    error_message = "If `true`, `redis_automatic_failover_enabled` must also be `true`, and more than one subnet must be specified within `redis_subnet_ids`."
  }
}

variable "redis_automatic_failover_enabled" {
  type        = bool
  description = "Boolean for deploying Redis nodes in multiple availability zones and enabling automatic failover."
  default     = true

  validation {
    condition     = var.redis_automatic_failover_enabled ? length(var.redis_subnet_ids) > 1 : true
    error_message = "If `true`, you must specify more than one subnet within `redis_subnet_ids`."
  }
}

variable "redis_at_rest_encryption_enabled" {
  type        = bool
  description = "Boolean to enable encryption at rest on Redis cluster. An AWS managed key will be used when `true` unless a value is also specified for `redis_kms_key_arn`."
  default     = true
}

variable "redis_kms_key_arn" {
  type        = string
  description = "ARN of KMS customer managed key (CMK) to encrypt Redis cluster with."
  default     = null

  validation {
    condition     = var.redis_kms_key_arn != null ? var.redis_at_rest_encryption_enabled : true
    error_message = "`redis_at_rest_encryption_enabled` must be set to `true` when specifying a KMS key ARN for Redis."
  }
}

variable "redis_transit_encryption_enabled" {
  type        = bool
  description = "Boolean to enable TLS encryption between TFE and the Redis cluster."
  default     = true
}

variable "redis_apply_immediately" {
  type        = bool
  description = "Boolean to apply changes immediately to Redis cluster."
  default     = true
}

variable "redis_auto_minor_version_upgrade" {
  type        = bool
  description = "Boolean to enable automatic minor version upgrades for Redis cluster."
  default     = true
}

variable "sg_allow_ingress_to_redis" {
  type        = string
  description = "Security group ID to allow TCP/6379 (Redis) inbound to Redis cluster."
  default     = null
}

variable "cidr_allow_ingress_to_redis" {
  type        = list(string)
  description = "List of CIDR ranges to allow TCP/6379 (Redis) inbound to Redis cluster."
  default     = null
}

#------------------------------------------------------------------------------
# Cost Estimation IAM
#------------------------------------------------------------------------------
variable "tfe_cost_estimation_iam_enabled" {
  type        = string
  description = "Boolean to add AWS pricing actions to TFE IAM role for service account (IRSA). Only implemented when `create_tfe_eks_irsa` is `true`."
  default     = true
}
