# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

resource "aws_security_group" "tfe_lb_allow" {
  count = var.create_tfe_lb_security_group ? 1 : 0

  name   = "${var.friendly_name_prefix}-tfe-lb-allow"
  vpc_id = var.vpc_id

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-lb-allow" },
    var.common_tags
  )
}

resource "aws_security_group_rule" "tfe_lb_allow_ingress_443" {
  count = var.create_tfe_lb_security_group ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.cidr_allow_ingress_tfe_443
  description       = "Allow TCP/443 (HTTPS) inbound to TFE load balancer from specified CIDR ranges."
  security_group_id = aws_security_group.tfe_lb_allow[0].id
}

resource "aws_security_group_rule" "tfe_lb_allow_all_egress_to_nodegroup" {
  count = var.create_tfe_lb_security_group && length(aws_security_group.tfe_eks_nodegroup_allow) > 0 ? 1 : 0

  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.tfe_eks_nodegroup_allow[0].id
  description              = "Allow all egress traffic outbound to node group from TFE load balancer."
  security_group_id        = aws_security_group.tfe_lb_allow[0].id
}

resource "aws_security_group_rule" "tfe_lb_allow_all_egress_to_cidr" {
  count = var.create_tfe_lb_security_group && var.cidr_allow_egress_from_tfe_lb != null ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = var.cidr_allow_egress_from_tfe_lb
  description       = "Allow all egress traffic outbound to specified CIDR ranges from TFE load balancer."
  security_group_id = aws_security_group.tfe_lb_allow[0].id
}

resource "aws_security_group_rule" "tfe_lb_allow_all_egress_to_sg" {
  count = var.create_tfe_lb_security_group && var.sg_allow_egress_from_tfe_lb != null ? 1 : 0

  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = var.sg_allow_egress_from_tfe_lb
  description              = "Allow all egress traffic outbound to specified security group from TFE load balancer."
  security_group_id        = aws_security_group.tfe_lb_allow[0].id
}