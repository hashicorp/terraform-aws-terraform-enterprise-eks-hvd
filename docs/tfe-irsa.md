# TFE IAM Role for Service Account (IRSA)

If you choose to create the TFE IAM Role for Service Account (IRSA) outside of this module, here are the permissions it would need. The permissions within the `aws_iam_policy_document` data resources with a `count` conditional are optional, depending on how you have configured your TFE infrastructure.

```hcl
#------------------------------------------------------------------------------
# IRSA for TFE
#------------------------------------------------------------------------------
resource "aws_iam_role" "tfe_irsa" {
  count = var.create_tfe_eks_irsa ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-eks-irsa-role-${data.aws_region.current.name}"
  path        = "/"
  description = "IAM role for TFE IRSA with TFE EKS cluster OIDC provider."

  assume_role_policy = data.aws_iam_policy_document.tfe_irsa_assume_role[0].json

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-eks-irsa-role-${data.aws_region.current.name}" },
    var.common_tags
  )
}

data "aws_iam_policy_document" "tfe_irsa_assume_role" {
  count = var.create_tfe_eks_irsa ? 1 : 0

  statement {
    sid     = "TfeIrsaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace("${local.oidc_provider_arn}", "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:${var.tfe_kube_namespace}:${var.tfe_kube_svc_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace("${local.oidc_provider_arn}", "/^(.*provider/)/", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "tfe_irsa_s3" {
  count = var.create_tfe_eks_irsa && var.tfe_object_storage_s3_use_instance_profile ? 1 : 0

  statement {
    sid    = "TfeIrsaAllowS3"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:GetBucketLocation"
    ]
    resources = [
      "${aws_s3_bucket.tfe.arn}",
      "${aws_s3_bucket.tfe.arn}/*"
    ]
  }
}

data "aws_iam_policy_document" "tfe_irsa_cost_estimation" {
  count = var.create_tfe_eks_irsa && var.tfe_cost_estimation_iam_enabled ? 1 : 0

  statement {
    sid    = "TfeIrsaAllowCostEstimation"
    effect = "Allow"
    actions = [
      "pricing:DescribeServices",
      "pricing:GetAttributeValues",
      "pricing:GetProducts"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "tfe_irsa_rds_kms_cmk" {
  count = var.create_tfe_eks_irsa && var.rds_kms_key_arn != null ? 1 : 0

  statement {
    sid    = "TfeIrsaAllowRdsKmsCmk"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:GenerateDataKey*"
    ]
    resources = [var.rds_kms_key_arn]
  }
}

data "aws_iam_policy_document" "tfe_irsa_s3_kms_cmk" {
  count = var.create_tfe_eks_irsa && var.rds_kms_key_arn != null ? 1 : 0

  statement {
    sid    = "TfeIrsaAllowS3KmsCmk"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:GenerateDataKey*"
    ]
    resources = [var.s3_kms_key_arn]
  }
}

data "aws_iam_policy_document" "tfe_irsa_redis_kms_cmk" {
  count = var.create_tfe_eks_irsa && var.redis_kms_key_arn != null ? 1 : 0

  statement {
    sid    = "TfeIrsaAllowRedisKmsCmk"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:GenerateDataKey*"
    ]
    resources = [var.redis_kms_key_arn]
  }
}

data "aws_iam_policy_document" "tfe_irsa_combined" {
  count = var.create_tfe_eks_irsa ? 1 : 0

  source_policy_documents = [
    var.tfe_object_storage_s3_use_instance_profile ? data.aws_iam_policy_document.tfe_irsa_s3[0].json : "",
    var.tfe_cost_estimation_iam_enabled ? data.aws_iam_policy_document.tfe_irsa_cost_estimation[0].json : "",
    var.rds_kms_key_arn != null ? data.aws_iam_policy_document.tfe_irsa_rds_kms_cmk[0].json : "",
    var.s3_kms_key_arn != null ? data.aws_iam_policy_document.tfe_irsa_s3_kms_cmk[0].json : "",
    var.redis_kms_key_arn != null ? data.aws_iam_policy_document.tfe_irsa_redis_kms_cmk[0].json : ""
  ]
}

resource "aws_iam_policy" "tfe_irsa" {
  count = var.create_tfe_eks_irsa ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-eks-irsa-policy-${data.aws_region.current.name}"
  description = "Custom IAM policy used to map TFE IAM role to TFE Kubernetes Service Account."
  policy      = data.aws_iam_policy_document.tfe_irsa_combined[0].json
}

resource "aws_iam_role_policy_attachment" "tfe_irsa" {
  count = var.create_tfe_eks_irsa ? 1 : 0

  role       = aws_iam_role.tfe_irsa[0].name
  policy_arn = aws_iam_policy.tfe_irsa[0].arn
}
```
