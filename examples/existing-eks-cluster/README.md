# Example: Existing EKS Cluster

This directory contains a ready-made Terraform configuration and an [example terraform.tfvars file](https://github.com/hashicorp/terraform-aws-terraform-enterprise-eks-hvd/blob/0.3.0/examples/existing-eks-cluster/terraform.tfvars.example) for deploying TFE supporting infrastructure against an **existing EKS cluster**. It provisions the same AWS infrastructure as the [new-eks-cluster](https://github.com/hashicorp/terraform-aws-terraform-enterprise-eks-hvd/blob/0.3.0/examples/new-eks-cluster) example (RDS, Redis, S3, IAM, Security Groups) but does **not** create an EKS cluster or node group.

> 📝 Note: This module provisions the AWS infrastructure layer only. The TFE application itself is installed separately via `helm` in the post-deployment steps and is not managed by Terraform.

For prerequisites, architectural decisions, and post-deployment steps, refer to the [new-eks-cluster README](https://github.com/hashicorp/terraform-aws-terraform-enterprise-eks-hvd/blob/0.3.0/examples/new-eks-cluster/README.md). For a full list of input variables and outputs, refer to the [root module README](https://github.com/hashicorp/terraform-aws-terraform-enterprise-eks-hvd/blob/0.3.0/README.md#inputs). The sections below cover only what differs in this example.

## When to Use This Example

Use this example when your EKS cluster is already provisioned and managed separately (e.g., by a platform or infrastructure team). If you want this module to also create the EKS cluster and node group, use the [new-eks-cluster](https://github.com/hashicorp/terraform-aws-terraform-enterprise-eks-hvd/blob/0.3.0/examples/new-eks-cluster) example instead.

## Differences from New EKS Cluster

### Variables Not Used

The following EKS-related variables from the `new-eks-cluster` example are not applicable here and should not be set:

- `create_eks_cluster`
- `eks_cluster_name`
- `eks_cluster_endpoint_public_access`
- `eks_cluster_public_access_cidrs`
- `eks_nodegroup_instance_type`
- `eks_nodegroup_scaling_config`

### Additional Required Inputs

Because the EKS cluster is managed outside this module, you must supply the following additional inputs so that security group rules can be correctly configured:

- `sg_allow_ingress_to_rds` — Security group ID of the EKS node group to allow TCP/5432 inbound to RDS
- `sg_allow_ingress_to_redis` — Security group ID of the EKS node group to allow TCP/6379 inbound to Redis
- `sg_allow_egress_from_tfe_lb` or `cidr_allow_egress_from_tfe_lb` — Target for egress from the TFE load balancer to EKS pods

### IAM — IRSA vs. Pod Identity

The same two options (IRSA and Pod Identity) apply, with one difference: since the OIDC provider may already exist on your cluster, set `create_eks_oidc_provider = false` and supply the existing provider details instead:

```hcl
create_eks_oidc_provider = false
eks_oidc_provider_arn    = "<existing-oidc-provider-arn>"
eks_oidc_provider_url    = "<existing-oidc-provider-url>"
```

For Pod Identity, supply the existing cluster name:

```hcl
create_tfe_eks_pod_identity = true
existing_eks_cluster_name   = "<existing-eks-cluster-name>"
```