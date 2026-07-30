# Example: New EKS Cluster

This directory contains a ready-made Terraform configuration and an [example terraform.tfvars file](./terraform.tfvars.example) for deploying TFE on a **new EKS cluster and node group** provisioned by this module, along with all supporting AWS infrastructure (RDS, Redis, S3, IAM, Security Groups). A Helm overrides file is also generated for the subsequent TFE installation.

> 📝 Note: This module provisions the AWS infrastructure layer only. The TFE application itself is installed separately via `helm` in the post-deployment steps and is not managed by Terraform.

For post-deployment steps, refer to the [Post Steps](../../README.md#post-steps) section in the root README. For a full list of input variables and outputs, refer to the [root module README](../../README.md#inputs).

## Prerequisites

The items below are specific to this example. Refer to the root module [Prerequisites](../../README.md#prerequisites) for the full list.

### AWS Region Configuration

Set the `region` variable to your target AWS region (e.g., `region = "us-east-1"`) in your `.tfvars` file.

### Networking

An existing VPC with private subnets is required. Supply subnet IDs for each tier separately:

- `vpc_id` — ID of the target VPC
- `eks_subnet_ids` — private subnets for the EKS node group
- `rds_subnet_ids` — private subnets for the RDS Aurora cluster
- `redis_subnet_ids` — private subnets for the ElastiCache Redis cluster

### Secrets Manager

The following plaintext secrets must exist in AWS Secrets Manager before running this module:

- `tfe_database_password_secret_arn` — RDS database password
- `tfe_redis_password_secret_arn` — Redis password

## Architectural Decisions

### EKS Cluster and Node Group

**Input variable:** `create_eks_cluster` (bool, default: `false`)

Set to `true` to have the module create a new EKS cluster and managed node group. Key related variables:

| Variable | Description | Default |
|---|---|---|
| `eks_cluster_name` | Name of the EKS cluster (prefixed by `friendly_name_prefix`) | `tfe-eks-cluster` |
| `eks_cluster_endpoint_public_access` | Enable public access to the EKS API endpoint | `false` |
| `eks_cluster_public_access_cidrs` | CIDR blocks for public endpoint access; required when above is `true` | `null` |
| `eks_nodegroup_instance_type` | EC2 instance type for worker nodes | `m7i.2xlarge` |
| `eks_nodegroup_scaling_config` | Desired, min, and max node counts | `{desired=3, max=3, min=2}` |

### IAM — IRSA vs. Pod Identity

TFE and the AWS Load Balancer Controller each require IAM permissions. This module supports two mechanisms; only one may be enabled per component at a time.

**Option A: IRSA (IAM Roles for Service Accounts)**

```hcl
create_eks_oidc_provider      = true
create_tfe_eks_irsa           = true
create_aws_lb_controller_irsa = true
```

`create_eks_oidc_provider` must be `true` when the OIDC provider does not already exist, which is the case when creating a new cluster.

**Option B: EKS Pod Identity**

```hcl
create_tfe_eks_pod_identity           = true
create_aws_lb_controller_pod_identity = true
```

> Only one of `create_tfe_eks_irsa` or `create_tfe_eks_pod_identity` may be `true` at a time. The same constraint applies to the AWS Load Balancer Controller equivalents.

### Helm Overrides File

**Input variable:** `create_helm_overrides_file` (bool, default: `true`)

When `true`, this module generates `./helm/module_generated_helm_overrides.yaml` in your working directory, populated with the provisioned resource endpoints (RDS, Redis, S3) and configuration values. This file is used as input to the Helm chart installation during the post-deployment steps.

Once you have customized and finalized this file, set `create_helm_overrides_file = false` in your `.tfvars` to prevent the module from overwriting it on subsequent runs.