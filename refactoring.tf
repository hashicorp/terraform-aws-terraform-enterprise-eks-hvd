# Resource name changes from:
# https://github.com/hashicorp/terraform-aws-terraform-enterprise-eks-hvd/pull/22/

moved {
  from = data.aws_iam_policy_document.tfe_irsa_s3
  to   = data.aws_iam_policy_document.tfe_workload_identity_s3
}

moved {
  from = data.aws_iam_policy_document.tfe_irsa_cost_estimation
  to   = data.aws_iam_policy_document.tfe_workload_identity_cost_estimation
}

moved {
  from = data.aws_iam_policy_document.tfe_irsa_rds_kms_cmk
  to   = data.aws_iam_policy_document.tfe_workload_identity_rds_kms_cmk
}

moved {
  from = data.aws_iam_policy_document.tfe_irsa_s3_kms_cmk
  to   = data.aws_iam_policy_document.tfe_workload_identity_s3_kms_cmk
}

moved {
  from = data.aws_iam_policy_document.tfe_irsa_redis_kms_cmk
  to   = data.aws_iam_policy_document.tfe_workload_identity_redis_kms_cmk
}

moved {
  from = data.aws_iam_policy_document.tfe_irsa_combined
  to   = data.aws_iam_policy_document.tfe_workload_identity_combined
}

moved {
  from = aws_iam_policy.tfe_irsa
  to   = aws_iam_policy.tfe_workload_identity
}
