# Deployment customizations

This doc contains various deployment customizations as it relates to creating your TFE infrastructure, and their corresponding module input variables that you may additionally set to meet your own requirements where the module default values do not suffice. That said, all of the module input variables on this page are optional.

## EKS

This module supports two deployment patterns for the EKS cluster that will run TFE:

1. **New EKS cluster** - the module creates a dedicated EKS cluster, node group, and associated security groups for TFE.
2. **Existing EKS cluster** - you bring your own EKS cluster (created outside of this module), and the module only manages the supporting AWS resources (IAM, RDS, Redis, S3, security groups) needed to run TFE on it.

Set `create_eks_cluster` to choose which pattern applies:

```hcl
create_eks_cluster = true # `true` to create a new EKS cluster and node group; `false` to bring your own existing EKS cluster
```

>📝 Note: See the [`new-eks-cluster`](../examples/new-eks-cluster/) and [`existing-eks-cluster`](../examples/existing-eks-cluster/) example directories for complete, runnable configurations of each pattern.

### New EKS cluster

When `create_eks_cluster` is `true`, the module provisions the `aws_eks_cluster`, an EKS access entry/policy association for the identity running Terraform, and the security groups required for the cluster and node group to communicate. The following variables let you customize the cluster:

```hcl
eks_cluster_name                   = "tfe-eks-cluster"    # will be prefixed with `friendly_name_prefix`
eks_cluster_authentication_mode    = "API_AND_CONFIG_MAP" # one of `API_AND_CONFIG_MAP`, `CONFIG_MAP`, or `API`
eks_cluster_endpoint_public_access = false                # `true` to enable a public API server endpoint
eks_cluster_public_access_cidrs    = ["<cidr-range>"]     # required when `eks_cluster_endpoint_public_access` is `true`
eks_cluster_service_ipv4_cidr      = "10.100.0.0/16"      # optional /16 CIDR for the Kubernetes service network; EKS auto-assigns from 10.100.0.0/16 or 172.20.0.0/16 when `null`
eks_subnet_ids                     = ["<subnet-id-a>", "<subnet-id-b>", "<subnet-id-c>"]
```

>📝 Note: The EKS cluster endpoint defaults to **private-only** access. Only enable `eks_cluster_endpoint_public_access` if your clients/workstations cannot reach the cluster over a private network path (VPN, Direct Connect, bastion, etc.), and always scope `eks_cluster_public_access_cidrs` as tightly as possible.

### Existing EKS cluster

When `create_eks_cluster` is `false`, set `existing_eks_cluster_name` if you want this module to manage Pod Identity (addon + associations) on that cluster:

```hcl
create_eks_cluster        = false
existing_eks_cluster_name = "<my-existing-eks-cluster-name>"
```

Because the module does not manage the cluster or node group's security groups in this scenario, you are responsible for ensuring the ingress/egress rules described in the module [README](../README.md#security-groups) are satisfied on your own node group/pod security groups. Use the following variables to wire the TFE load balancer security group (managed by this module) to your existing node group/pod security group:

```hcl
cidr_allow_egress_from_tfe_lb = ["<tfe-pod-cidr-range>"] # only when bringing your own EKS cluster; must be `null` when `create_eks_cluster` is `true`
sg_allow_egress_from_tfe_lb   = "<existing-nodegroup-or-pod-security-group-id>" # only when bringing your own EKS cluster; must be `null` when `create_eks_cluster` is `true`
```

### EC2 node group customization

When the module creates the EKS cluster (`create_eks_cluster = true`), it also creates a managed `aws_eks_node_group` backed by an `aws_launch_template` that controls the underlying EC2 worker node configuration. The following variables let you tune the EC2 instances that back the node group:

```hcl
eks_nodegroup_name          = "tfe-eks-nodegroup"      # will be prefixed with `friendly_name_prefix`
eks_nodegroup_instance_type = "m7i.2xlarge"            # EC2 instance type for worker nodes
eks_nodegroup_ami_type      = "AL2023_x86_64_STANDARD" # or `AL2023_ARM_64_STANDARD`, `BOTTLEROCKET_x86_64`, etc.
eks_nodegroup_scaling_config = {
  desired_size = 3
  max_size     = 3
  min_size     = 2
}
```

To use a custom/hardened AMI for the worker nodes instead of the latest AWS-owned AMI for the selected `eks_nodegroup_ami_type`, set `eks_nodegroup_ami_type` to `CUSTOM` and provide the AMI ID:

```hcl
eks_nodegroup_ami_type = "CUSTOM"
eks_nodegroup_ami_id   = "<my-custom-ami-id>"
```

>📝 Note: The launch template always enforces IMDSv2 (`http_tokens = "required"`) and encrypts the root EBS volume by default. To encrypt the EBS volume with a customer-managed KMS key instead of the AWS-managed key, see the [KMS](#kms) section below.

To run custom bootstrap logic on worker nodes at launch (_e.g._ additional `containerd`/`kubelet` configuration, custom `nodeadm`/bootstrap scripts, host hardening), set `eks_nodegroup_user_data` to the path of a Terraform template file (`.tftpl` or `.tpl` extension):

```hcl
eks_nodegroup_user_data = "${path.module}/templates/my-nodegroup-user-data.sh.tftpl"
```

The module renders the template via `templatefile()` and automatically base64-encodes the result before applying it as the launch template's `user_data`, so your template must contain the raw (non-base64) user data content. Two variables are available for interpolation inside the template:

| Template variable | Description |
|---|---|
| `cluster_certificate_authority_data` | Base64-encoded certificate authority data for the EKS cluster (from `aws_eks_cluster.tfe[0].certificate_authority[0].data`). |
| `cluster_endpoint` | `<eks-cluster-name>.<region>.eks.amazonaws.com`, derived from the created `aws_eks_cluster.tfe` resource name and the current AWS region. |

Example template file:

```sh
#!/bin/bash
# my-nodegroup-user-data.sh.tftpl
echo "${cluster_certificate_authority_data}" | base64 -d > /etc/kubernetes/pki/ca.crt
echo "Bootstrapping against ${cluster_endpoint}"
```

>📝 Note: `eks_nodegroup_user_data` defaults to `null`. When left `null`, no `user_data` argument is applied to the `aws_launch_template` resource and the selected AMI's default bootstrap behavior is used unmodified. When set, the value must be `null` or a path to an existing file with a `.tftpl` or `.tpl` extension; other values fail variable validation.

### IAM roles for service accounts (IRSA) vs. Pod Identity

TFE and the AWS Load Balancer Controller each need an EKS-native way to assume an AWS IAM role from within the cluster. This module supports both of the AWS-supported mechanisms; choose one per workload (you cannot enable both IRSA and Pod Identity for the same workload):

```hcl
# --- TFE ---
create_tfe_eks_irsa         = true  # IRSA; requires an OIDC provider (set `create_eks_oidc_provider = true`, or set `create_eks_oidc_provider = false` and provide `eks_oidc_provider_arn`)
create_tfe_eks_pod_identity = false # Pod Identity; requires `create_eks_cluster = true` or a valid `existing_eks_cluster_name`

# --- AWS Load Balancer Controller ---
create_aws_lb_controller_irsa         = true
create_aws_lb_controller_pod_identity = false
```

If you choose IRSA for an existing EKS cluster, either have this module create the OIDC provider (requires the cluster issuer URL when `create_eks_cluster = false`), or reference an existing OIDC provider:

```hcl
# Option A: create the OIDC provider
create_eks_oidc_provider = true
eks_oidc_provider_url    = "<eks-oidc-issuer-url>"

# Option B: use an existing OIDC provider
create_eks_oidc_provider = false
eks_oidc_provider_arn    = "<existing-oidc-provider-arn>"
```

If you choose Pod Identity, the module creates the `eks-pod-identity-agent` EKS addon automatically (pin its version with `eks_pod_identity_addon_version`, or leave `null` to use the latest).

Both mechanisms rely on the Kubernetes namespace/service account names that the TFE and AWS Load Balancer Controller Helm charts create; override these only if you changed the defaults in your Helm values:

```hcl
tfe_kube_namespace                 = "tfe"
tfe_kube_svc_account               = "tfe"
aws_lb_controller_kube_namespace   = "kube-system"
aws_lb_controller_kube_svc_account = "aws-load-balancer-controller"
```

## KMS

If you require the use of a customer-managed key(s) (CMK) to encrypt your AWS resources, the following module input variables may be set:

```hcl
rds_kms_key_arn               = "<rds-kms-key-arn>"
s3_kms_key_arn                = "<s3-kms-key-arn>"
redis_kms_key_arn             = "<redis-kms-key-arn>"
eks_nodegroup_ebs_kms_key_arn = "<ebs-kms-key-arn>"
```
