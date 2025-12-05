# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# EKS cluster
#------------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster" {
  count = var.create_eks_cluster ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-eks-cluster-role-${data.aws_region.current.name}"
  path        = "/"
  description = "IAM role for TFE EKS cluster."

  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role[0].json

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-eks-cluster-role-${data.aws_region.current.name}" },
    var.common_tags
  )

  permissions_boundary = var.role_permissions_boundary
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  count = var.create_eks_cluster ? 1 : 0

  statement {
    sid     = "EksClusterAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_cluster_policy" {
  count = var.create_eks_cluster ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_service_policy" {
  count = var.create_eks_cluster ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_vpc_resource_controller_policy" {
  count = var.create_eks_cluster ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster[0].name
}

// Potentially add a log group deny policy (customer inline)
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Action": [
#                 "logs:CreateLogGroup"
#             ],
#             "Effect": "Deny",
#             "Resource": "*"
#         }
#     ]
# }

// Potentially add a KMS allow policy (customer managed)
# {
#     "Statement": [
#         {
#             "Action": [
#                 "kms:Encrypt",
#                 "kms:Decrypt",
#                 "kms:ListGrants",
#                 "kms:DescribeKey"
#             ],
#             "Effect": "Allow",
#             "Resource": "arn:aws:kms:us-east-1:123456789:key/7ed9c3ee-8b42-4889-8404-1e653e6a804a"
#         }
#     ],
#     "Version": "2012-10-17"
# }

#------------------------------------------------------------------------------
# EKS node group
#------------------------------------------------------------------------------
resource "aws_iam_role" "tfe_eks_nodegroup" {
  count = var.create_eks_cluster ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-eks-node-group-role-${data.aws_region.current.name}"
  path        = "/"
  description = "IAM role for TFE EKS node group."

  assume_role_policy = data.aws_iam_policy_document.tfe_eks_nodegroup_assume_role[0].json

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-eks-node-group-role-${data.aws_region.current.name}" },
    var.common_tags
  )

  permissions_boundary = var.role_permissions_boundary
}

data "aws_iam_policy_document" "tfe_eks_nodegroup_assume_role" {
  count = var.create_eks_cluster ? 1 : 0

  statement {
    sid     = "TfeEksNodeGroupAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "tfe_eks_nodegroup_worker_node_policy" {
  count = var.create_eks_cluster ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.tfe_eks_nodegroup[0].name
}

resource "aws_iam_role_policy_attachment" "tfe_eks_nodegroup_cni_policy" {
  count = var.create_eks_cluster ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.tfe_eks_nodegroup[0].name
}

resource "aws_iam_role_policy_attachment" "tfe_eks_nodegroup_container_registry_readonly" {
  count = var.create_eks_cluster ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.tfe_eks_nodegroup[0].name
}

resource "aws_iam_policy" "tfe_eks_nodegroup_custom" {
  count = var.create_eks_cluster && var.eks_nodegroup_ebs_kms_key_arn != null ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-eks-node-group-custom-policy-${data.aws_region.current.name}"
  description = "Custom IAM policy to grant TKE EKS node group access to KMS customer-managed key (CMK)."
  policy      = data.aws_iam_policy_document.tfe_eks_nodegroup_ebs_kms_cmk[0].json
}

data "aws_iam_policy_document" "tfe_eks_nodegroup_ebs_kms_cmk" {
  count = var.create_eks_cluster && var.eks_nodegroup_ebs_kms_key_arn != null ? 1 : 0

  statement {
    sid    = "AllowTfeEksNodeGroupEbsKmsCmk"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:ReEncrypt*"
    ]
    resources = [var.eks_nodegroup_ebs_kms_key_arn]
  }
}

// If in the future, any additional custom aws_iam_policy_document resources are added,
// a "combined" aws_iam_policy_document should be created to aggregate the multiple policy
// documents into a single policy document to reference in `aws_iam_policy.eks_nodegroup_custom`.

resource "aws_iam_role_policy_attachment" "tfe_eks_nodegroup_ebs_kms" {
  count = var.create_eks_cluster && var.eks_nodegroup_ebs_kms_key_arn != null ? 1 : 0

  role       = aws_iam_role.tfe_eks_nodegroup[0].name
  policy_arn = aws_iam_policy.tfe_eks_nodegroup_custom[0].arn
}

// Instance Profile not needed here because EKS/K8s will automatically create one itself based on the IAM role arn
# resource "aws_iam_instance_profile" "eks_nodegroup" {
#   name = "${var.friendly_name_prefix}-tfe-eks-node-group-instance-profile-${data.aws_region.current.name}"
#   role = aws_iam_role.eks_nodegroup.name
# }

locals {
  workload_identity_type = var.create_tfe_eks_irsa ? "Irsa" : (var.create_tfe_eks_pod_identity ? "PodIdentity" : null)
}

#------------------------------------------------------------------------------
# IAM role for service account (IRSA) setup
#------------------------------------------------------------------------------
data "tls_certificate" "tfe_eks" {
  count = var.create_eks_oidc_provider ? 1 : 0

  url = var.create_eks_cluster ? aws_eks_cluster.tfe[0].identity[0].oidc[0].issuer : var.eks_oidc_provider_url
}

resource "aws_iam_openid_connect_provider" "tfe_eks_irsa" {
  count = var.create_eks_oidc_provider ? 1 : 0

  url             = var.create_eks_cluster ? aws_eks_cluster.tfe[0].identity[0].oidc[0].issuer : var.eks_oidc_provider_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tfe_eks[0].certificates[0].sha1_fingerprint]

  tags = merge(
    { Name = "${var.friendly_name_prefix}-tfe-eks-irsa" },
    var.common_tags
  )
}

locals {
  oidc_provider_arn = var.create_eks_oidc_provider ? aws_iam_openid_connect_provider.tfe_eks_irsa[0].arn : var.eks_oidc_provider_arn
}

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

  permissions_boundary = var.role_permissions_boundary
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

#------------------------------------------------------------------------------
# Pod Identity for TFE
#------------------------------------------------------------------------------
resource "aws_iam_role" "tfe_pi" {
  count = var.create_tfe_eks_pod_identity ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-eks-pi-role-${data.aws_region.current.name}"
  path        = "/"
  description = "IAM role for TFE Pod Identity."

  assume_role_policy = data.aws_iam_policy_document.tfe_pi_assume_role[0].json

}

data "aws_iam_policy_document" "tfe_pi_assume_role" {
  count = var.create_tfe_eks_pod_identity ? 1 : 0

  statement {
    sid     = "TfePiAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "tfe_workload_identity_s3" {
  count = (var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity) && var.tfe_object_storage_s3_use_instance_profile ? 1 : 0

  statement {
    sid    = "Tfe${local.workload_identity_type}AllowS3"
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

data "aws_iam_policy_document" "tfe_workload_identity_cost_estimation" {
  count = (var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity) && var.tfe_cost_estimation_iam_enabled ? 1 : 0

  statement {
    sid    = "Tfe${local.workload_identity_type}AllowCostEstimation"
    effect = "Allow"
    actions = [
      "pricing:DescribeServices",
      "pricing:GetAttributeValues",
      "pricing:GetProducts"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "tfe_workload_identity_rds_kms_cmk" {
  count = (var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity) && var.rds_kms_key_arn != null ? 1 : 0

  statement {
    sid    = "Tfe${local.workload_identity_type}AllowRdsKmsCmk"
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

data "aws_iam_policy_document" "tfe_workload_identity_s3_kms_cmk" {
  count = (var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity) && var.rds_kms_key_arn != null ? 1 : 0

  statement {
    sid    = "Tfe${local.workload_identity_type}AllowS3KmsCmk"
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

data "aws_iam_policy_document" "tfe_workload_identity_redis_kms_cmk" {
  count = (var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity) && var.redis_kms_key_arn != null ? 1 : 0

  statement {
    sid    = "Tfe${local.workload_identity_type}AllowRedisKmsCmk"
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

data "aws_iam_policy_document" "tfe_workload_identity_combined" {
  count = (var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity) ? 1 : 0

  source_policy_documents = [
    var.tfe_object_storage_s3_use_instance_profile ? data.aws_iam_policy_document.tfe_workload_identity_s3[0].json : "",
    var.tfe_cost_estimation_iam_enabled ? data.aws_iam_policy_document.tfe_workload_identity_cost_estimation[0].json : "",
    var.rds_kms_key_arn != null ? data.aws_iam_policy_document.tfe_workload_identity_rds_kms_cmk[0].json : "",
    var.s3_kms_key_arn != null ? data.aws_iam_policy_document.tfe_workload_identity_s3_kms_cmk[0].json : "",
    var.redis_kms_key_arn != null ? data.aws_iam_policy_document.tfe_workload_identity_redis_kms_cmk[0].json : ""
  ]
}

resource "aws_iam_policy" "tfe_workload_identity" {
  count = (var.create_tfe_eks_irsa || var.create_tfe_eks_pod_identity) ? 1 : 0

  name        = "${var.friendly_name_prefix}-tfe-eks-irsa-policy-${data.aws_region.current.name}"
  description = "Custom IAM policy used to map TFE IAM role to TFE Kubernetes Service Account."
  policy      = data.aws_iam_policy_document.tfe_workload_identity_combined[0].json
}

resource "aws_iam_role_policy_attachment" "tfe_irsa" {
  count = var.create_tfe_eks_irsa ? 1 : 0

  role       = aws_iam_role.tfe_irsa[0].name
  policy_arn = aws_iam_policy.tfe_workload_identity[0].arn
}

resource "aws_iam_role_policy_attachment" "tfe_pi" {
  count = var.create_tfe_eks_pod_identity ? 1 : 0

  role       = aws_iam_role.tfe_pi[0].name
  policy_arn = aws_iam_policy.tfe_workload_identity[0].arn
}

resource "aws_eks_pod_identity_association" "tfe_association" {
  count = var.create_tfe_eks_pod_identity ? 1 : 0

  cluster_name    = var.create_eks_cluster ? aws_eks_cluster.tfe[0].name : var.existing_eks_cluster_name
  namespace       = var.tfe_kube_namespace
  service_account = var.tfe_kube_svc_account
  role_arn        = aws_iam_role.tfe_pi[0].arn
}

#------------------------------------------------------------------------------
# IRSA for AWS load balancer controller
#------------------------------------------------------------------------------
resource "aws_iam_role" "aws_lb_controller_irsa" {
  count = var.create_aws_lb_controller_irsa ? 1 : 0

  name        = "${var.friendly_name_prefix}-aws-lb-controller-irsa-role-${data.aws_region.current.name}"
  path        = "/"
  description = "IAM role for AWS Load Balancer Controller IRSA with TFE EKS cluster OIDC provider."

  assume_role_policy = data.aws_iam_policy_document.aws_lb_controller_irsa_assume_role[0].json

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-aws-lb-controller-irsa-role-${data.aws_region.current.name}" },
    var.common_tags
  )

  permissions_boundary = var.role_permissions_boundary
}

data "aws_iam_policy_document" "aws_lb_controller_irsa_assume_role" {
  count = var.create_aws_lb_controller_irsa ? 1 : 0

  statement {
    sid     = "AWSLoadBalancerControllerIrsaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace("${local.oidc_provider_arn}", "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:${var.aws_lb_controller_kube_namespace}:${var.aws_lb_controller_kube_svc_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace("${local.oidc_provider_arn}", "/^(.*provider/)/", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

#------------------------------------------------------------------------------
# Pod Identity for LB controller
#------------------------------------------------------------------------------
resource "aws_iam_role" "aws_lb_pi" {
  count = var.create_aws_lb_controller_pod_identity ? 1 : 0

  name        = "${var.friendly_name_prefix}-aws-lb-controller-pi-role-${data.aws_region.current.name}"
  path        = "/"
  description = "IAM role for AWS Loead Balancer Controller Pod Identity."

  assume_role_policy = data.aws_iam_policy_document.aws_lb_pi_assume_role[0].json

}

data "aws_iam_policy_document" "aws_lb_pi_assume_role" {
  count = var.create_aws_lb_controller_pod_identity ? 1 : 0

  statement {
    sid     = "TfePiAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  count = (var.create_aws_lb_controller_irsa || var.create_aws_lb_controller_pod_identity) ? 1 : 0

  name        = "${var.friendly_name_prefix}-aws-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller."
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller_policy[0].json
}

# Source: https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.0/docs/install/iam_policy.json
data "aws_iam_policy_document" "aws_load_balancer_controller_policy" {
  count = (var.create_aws_lb_controller_irsa || var.create_aws_lb_controller_pod_identity) ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTrustStores",
      "elasticloadbalancing:DescribeListenerAttributes"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListenerAttributes"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values   = ["CreateTargetGroup", "CreateLoadBalancer"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  count = var.create_aws_lb_controller_irsa ? 1 : 0

  role       = aws_iam_role.aws_lb_controller_irsa[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "aws_lb_pi_policy_attachment" {
  count = var.create_aws_lb_controller_pod_identity ? 1 : 0

  role       = aws_iam_role.aws_lb_pi[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy[0].arn
}

resource "aws_eks_pod_identity_association" "aws_lb_controller_association" {
  count = var.create_aws_lb_controller_pod_identity ? 1 : 0

  cluster_name    = var.create_eks_cluster ? aws_eks_cluster.tfe[0].name : var.existing_eks_cluster_name
  namespace       = var.aws_lb_controller_kube_namespace
  service_account = var.aws_lb_controller_kube_svc_account
  role_arn        = aws_iam_role.aws_lb_pi[0].arn
}
