# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# EKS node group
#------------------------------------------------------------------------------
resource "aws_eks_node_group" "tfe" {
  count = var.create_eks_cluster ? 1 : 0

  cluster_name    = aws_eks_cluster.tfe[0].name
  node_group_name = "${var.friendly_name_prefix}-${var.eks_nodegroup_name}"
  node_role_arn   = aws_iam_role.tfe_eks_nodegroup[0].arn
  subnet_ids      = var.eks_subnet_ids
  capacity_type   = "ON_DEMAND"
  instance_types  = [var.eks_nodegroup_instance_type]
  ami_type        = var.eks_nodegroup_ami_type

  launch_template {
    id      = aws_launch_template.tfe_eks_nodegroup[0].id
    version = aws_launch_template.tfe_eks_nodegroup[0].latest_version
  }

  scaling_config {
    desired_size = var.eks_nodegroup_scaling_config["desired_size"]
    max_size     = var.eks_nodegroup_scaling_config["max_size"]
    min_size     = var.eks_nodegroup_scaling_config["min_size"]
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-${var.eks_nodegroup_name}" },
    var.common_tags
  )
}

#------------------------------------------------------------------------------
# Launch template
#------------------------------------------------------------------------------
data "aws_ami" "tfe_eks_nodegroup_custom" {
  count = var.eks_nodegroup_ami_id != null ? 1 : 0

  filter {
    name   = "image-id"
    values = [var.eks_nodegroup_ami_id]
  }
}

locals {
  eks_default_ami_map = {
    // https://github.com/awslabs/amazon-eks-ami/releases
    AL2023_ARM_64_STANDARD     = "al2023-ami-minimal-2023.*-arm64"
    AL2023_x86_64_STANDARD     = "al2023-ami-minimal-2023.*-x86_64"
    AL2_ARM_64                 = "amzn2-ami-minimal-hvm-2.0.*-arm64-ebs"
    AL2_x86_64                 = "amzn2-ami-minimal-hvm-2.0.*-x86_64-ebs"
    AL2_x86_64_GPU             = "amzn2-ami-minimal-hvm-2.0.*-x86_64-ebs"
    BOTTLEROCKET_ARM_64        = "bottlerocket-aws-k8s-*-aarch64-*"
    BOTTLEROCKET_x86_64        = "bottlerocket-aws-k8s-*-x86_64-*"
    BOTTLEROCKET_ARM_64_NVIDIA = "bottlerocket-aws-k8s-*-nvidia-aarch64-*"
    BOTTLEROCKET_x86_64_NVIDIA = "bottlerocket-aws-k8s-*-nvidia-x86_64-*"
  }
}

data "aws_ami" "tfe_eks_nodegroup_default" {
  count = var.eks_nodegroup_ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [lookup(local.eks_default_ami_map, var.eks_nodegroup_ami_type)]
  }
}

resource "aws_launch_template" "tfe_eks_nodegroup" {
  count = var.create_eks_cluster ? 1 : 0

  name     = "${var.friendly_name_prefix}-${var.eks_nodegroup_name}-launch-template"
  image_id = var.eks_nodegroup_ami_id

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.tfe_eks_nodegroup_allow[0].id]
  }

  block_device_mappings {
    device_name = var.eks_nodegroup_ami_id != null ? data.aws_ami.tfe_eks_nodegroup_custom[0].root_device_name : data.aws_ami.tfe_eks_nodegroup_default[0].root_device_name

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.eks_nodegroup_ebs_kms_key_arn
    }
  }

  ebs_optimized = true

  // https://support.hashicorp.com/hc/en-us/articles/35213717169427-Terraform-Enterprise-FDO-fails-to-start-with-EKS-version-1-30
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    instance_metadata_tags      = "disabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.friendly_name_prefix}-tfe-eks-private-node"
    }
  }
}

#------------------------------------------------------------------------------
# Security groups
#------------------------------------------------------------------------------
resource "aws_security_group" "tfe_eks_nodegroup_allow" {
  count = var.create_eks_cluster ? 1 : 0

  name   = "${var.friendly_name_prefix}-tfe-eks-nodegroup-allow"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.friendly_name_prefix}-tfe-eks-nodegroup-allow" }, var.common_tags)
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_443_from_lb" {
  count = var.create_eks_cluster && length(aws_security_group.tfe_lb_allow) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tfe_lb_allow[0].id
  description              = "Allow TCP/443 (HTTPS) inbound to node group from TFE load balancer."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_tfe_http_from_lb" {
  count = var.create_eks_cluster && length(aws_security_group.tfe_lb_allow) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = var.tfe_http_port
  to_port                  = var.tfe_http_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tfe_lb_allow[0].id
  description              = "Allow TCP/8080 or specified port (TFE HTTP) inbound to node group from TFE load balancer."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_tfe_https_from_lb" {
  count = var.create_eks_cluster && length(aws_security_group.tfe_lb_allow) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = var.tfe_https_port
  to_port                  = var.tfe_https_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tfe_lb_allow[0].id
  description              = "Allow TCP/8443 or specified port (TFE HTTPS) inbound to node group from TFE load balancer."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_tfe_metrics_http_from_cidr" {
  count = var.cidr_allow_ingress_tfe_metrics_http != null ? 1 : 0

  type        = "ingress"
  from_port   = var.tfe_metrics_http_port
  to_port     = var.tfe_metrics_http_port
  protocol    = "tcp"
  cidr_blocks = var.cidr_allow_ingress_tfe_metrics_http
  description = "Allow TCP/9090 or specified port (TFE HTTP metrics endpoint) inbound to node group from specified CIDR ranges."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_tfe_metrics_https_from_cidr" {
  count = var.cidr_allow_ingress_tfe_metrics_https != null ? 1 : 0

  type        = "ingress"
  from_port   = var.tfe_metrics_https_port
  to_port     = var.tfe_metrics_https_port
  protocol    = "tcp"
  cidr_blocks = var.cidr_allow_ingress_tfe_metrics_https
  description = "Allow TCP/9091 or specified port (TFE HTTPS metrics endpoint) inbound to node group from specified CIDR ranges."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_443_from_cluster" {
  count = var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_allow[0].id
  description              = "Allow TCP/443 (Cluster API) inbound to node group from EKS cluster (cluster API)."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_10250_from_cluster" {
  count = var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_allow[0].id
  description              = "Allow TCP/10250 (kubelet) inbound to node group from EKS cluster (cluster API)."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_4443_from_cluster" {
  count = var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 4443
  to_port                  = 4443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_allow[0].id
  description              = "Allow TCP/4443 (webhooks) inbound to node group from EKS cluster (cluster API)."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_9443_from_cluster" {
  count = var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_allow[0].id
  description              = "Allow TCP/9443 (ALB controller, NGINX) inbound to node group from EKS cluster (cluster API)."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_6443_from_cluster" {
  count = var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_allow[0].id
  description              = "Allow TCP/6443 (prometheus-adapter) inbound to node group from EKS cluster (cluster API)."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_8443_from_cluster" {
  count = var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_allow[0].id
  description              = "Allow TCP/8443 (Karpenter) inbound to node group from EKS cluster (cluster API)."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_nodes_53_tcp" {
  count = var.create_eks_cluster ? 1 : 0

  type        = "ingress"
  from_port   = 53
  to_port     = 53
  protocol    = "tcp"
  self        = true
  description = "Allow TCP/53 (CoreDNS) inbound between nodes in node group."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_nodes_53_udp" {
  count = var.create_eks_cluster ? 1 : 0

  type        = "ingress"
  from_port   = 53
  to_port     = 53
  protocol    = "udp"
  self        = true
  description = "Allow UDP/53 (CoreDNS) inbound between nodes in node group."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_nodes_ephemeral" {
  count = var.create_eks_cluster ? 1 : 0

  type        = "ingress"
  from_port   = 1025
  to_port     = 65535
  protocol    = "tcp"
  self        = true
  description = "Allow TCP/1025-TCP/65535 (ephemeral ports) inbound between nodes in node group."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}

resource "aws_security_group_rule" "tfe_eks_nodegroup_allow_all_egress" {
  count = var.create_eks_cluster ? 1 : 0

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow all outbound traffic from node group."

  security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
}