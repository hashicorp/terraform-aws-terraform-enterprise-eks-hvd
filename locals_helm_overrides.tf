# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

locals {
  helm_overrides_values = {
    # Service account
    create_service_account = var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity
    tfe_eks_irsa_arn       = var.create_tfe_eks_irsa ? aws_iam_role.tfe_irsa[0].arn : ""
    tfe_kube_svc_account   = var.tfe_kube_svc_account

    # Service annotations
    tfe_lb_security_groups = var.create_tfe_lb_security_group ? aws_security_group.tfe_lb_allow[0].id : ""

    # TFE configuration settings
    tfe_hostname           = var.tfe_fqdn
    tfe_http_port          = var.tfe_http_port
    tfe_https_port         = var.tfe_https_port
    tfe_metrics_http_port  = var.tfe_metrics_http_port
    tfe_metrics_https_port = var.tfe_metrics_https_port

    # Database settings
    tfe_database_host       = "${aws_rds_cluster.tfe.endpoint}:5432"
    tfe_database_name       = aws_rds_cluster.tfe.database_name
    tfe_database_user       = aws_rds_cluster.tfe.master_username
    tfe_database_parameters = var.tfe_database_parameters

    # Object storage settings
    tfe_object_storage_type                                 = "s3"
    tfe_object_storage_s3_bucket                            = aws_s3_bucket.tfe.id
    tfe_object_storage_s3_region                            = data.aws_region.current.name
    tfe_object_storage_s3_endpoint                          = "" # needed for GovCloud?
    tfe_object_storage_s3_use_instance_profile              = var.tfe_object_storage_s3_use_instance_profile
    tfe_object_storage_s3_access_key_id                     = var.tfe_object_storage_s3_access_key_id == null ? "" : var.tfe_object_storage_s3_access_key_id
    tfe_object_storage_s3_secret_access_key                 = var.tfe_object_storage_s3_secret_access_key == null ? "" : var.tfe_object_storage_s3_secret_access_key
    tfe_object_storage_s3_server_side_encryption            = var.s3_kms_key_arn == null ? "AES256" : "aws:kms"
    tfe_object_storage_s3_server_side_encryption_kms_key_id = var.s3_kms_key_arn == null ? "" : var.s3_kms_key_arn

    # Redis settings
    tfe_redis_host     = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
    tfe_redis_use_auth = var.tfe_redis_password_secret_arn != null ? true : false
    tfe_redis_use_tls  = var.redis_transit_encryption_enabled
  }
}

resource "local_file" "helm_overrides_values" {
  count = var.create_helm_overrides_file ? 1 : 0

  content  = templatefile("${path.module}/templates/helm_overrides_values.yaml.tpl", local.helm_overrides_values)
  filename = "${path.cwd}/helm/module_generated_helm_overrides.yaml"

  lifecycle {
    ignore_changes = [content, filename]
  }
}
