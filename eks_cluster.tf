# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# EKS cluster
#------------------------------------------------------------------------------
resource "aws_eks_cluster" "tfe" {
  count = var.create_eks_cluster ? 1 : 0

  name     = "${var.friendly_name_prefix}-${var.eks_cluster_name}"
  role_arn = aws_iam_role.eks_cluster[0].arn

  access_config {
    authentication_mode                         = var.eks_cluster_authentication_mode
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    security_group_ids      = [aws_security_group.eks_cluster_allow[0].id]
    subnet_ids              = var.eks_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.eks_cluster_endpoint_public_access
    public_access_cidrs     = var.eks_cluster_public_access_cidrs
  }

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = var.eks_cluster_service_ipv4_cidr # EKS auto assigns from 10.100.0.0/16 or 172.20.0.0/16 CIDR blocks when `null`
    service_ipv6_cidr = null
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-${var.eks_cluster_name}" },
    var.common_tags
  )

  # lifecycle {
  #   ignore_changes = [
  #     access_config[0].bootstrap_cluster_creator_admin_permissions
  #   ]
  # }
}

resource "aws_eks_access_entry" "tfe_cluster_creator" {
  count = var.create_eks_cluster ? 1 : 0

  cluster_name      = aws_eks_cluster.tfe[0].name
  kubernetes_groups = null
  principal_arn     = data.aws_iam_session_context.current.issuer_arn
  type              = "STANDARD"
  user_name         = null

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-${var.eks_cluster_name}-access-entry" },
    var.common_tags
  )
}

resource "aws_eks_access_policy_association" "tfe_cluster_creator" {
  count = var.create_eks_cluster ? 1 : 0

  access_scope {
    type       = "cluster"
    namespaces = []
  }

  cluster_name = aws_eks_cluster.tfe[0].name

  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_iam_session_context.current.issuer_arn

  # depends_on = [
  #   aws_eks_access_entry.tfe_cluster_creator,
  # ]
}

#------------------------------------------------------------------------------
# Security groups
#------------------------------------------------------------------------------
resource "aws_security_group" "eks_cluster_allow" {
  count = var.create_eks_cluster ? 1 : 0

  name   = "${var.friendly_name_prefix}-tfe-eks-cluster-allow"
  vpc_id = var.vpc_id

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-eks-allow" },
    var.common_tags
  )
}

resource "aws_security_group_rule" "eks_cluster_allow_ingress_nodegroup" {
  count = var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
  description              = "Allow TCP/443 (HTTPS) inbound to EKS cluster from node group."
  security_group_id        = aws_security_group.eks_cluster_allow[0].id
}

resource "aws_security_group_rule" "eks_cluster_allow_all_egress" {
  count = var.create_eks_cluster ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from EKS cluster."
  security_group_id = aws_security_group.eks_cluster_allow[0].id
}

#------------------------------------------------------------------------------
# Pod Identity
#------------------------------------------------------------------------------
resource "aws_eks_addon" "pod_identity" {
  count = (var.create_tfe_eks_pod_identity || var.create_aws_lb_controller_pod_identity) ? 1 : 0

  cluster_name  = var.create_eks_cluster ? aws_eks_cluster.tfe[0].name : var.existing_eks_cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = var.eks_pod_identity_addon_version
}
