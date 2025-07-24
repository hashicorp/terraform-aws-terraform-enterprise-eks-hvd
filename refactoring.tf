# Resource name changed from:
# https://github.com/hashicorp/terraform-aws-terraform-enterprise-eks-hvd/pull/22/

moved {
  from = aws_iam_policy.tfe_irsa
  to   = aws_iam_policy.tfe_workload_identity
}
