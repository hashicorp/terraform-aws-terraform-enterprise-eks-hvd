# Terraform Enterprise HVD on AWS EKS

Terraform module aligned with HashiCorp Validated Designs (HVD) to deploy Terraform Enterprise on AWS Elastic Kubernetes Service (EKS). This module supports bringing your own EKS cluster, or optionally creating a new EKS cluster dedicated to running TFE. This module does not use the Kubernetes or Helm Terraform providers, but rather includes [Post Steps](#post-steps) for the application layer portion of the deployment leveraging the `kubectl` and `helm` CLIs.

## Prerequisites

### General

- TFE license file (_e.g._ `terraform.hclic`)
- Terraform CLI `>= 1.9` installed on clients/workstations that will be used to deploy TFE
- General understanding of how to use Terraform (Community Edition)
- General understanding of how to use AWS
- General understanding of how to use Kubernetes and Helm
- `git` CLI and Visual Studio Code editor installed on workstations are strongly recommended
- AWS account that TFE will be deployed in with permissions to provision these [resources](#resources) via Terraform CLI
- (Optional) AWS S3 bucket for [S3 remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3) that will be used to manage the Terraform state of this TFE deployment (out-of-band from the TFE application) via Terraform CLI (Community Edition)

### Networking

- AWS VPC ID and the following subnets:
  - Load balancer subnet IDs (can be the same as EKS subnets if desired)
  - EKS (compute) subnet IDs for TFE pods
  - RDS (database) subnet IDs
  - Redis subnet IDs (can be the same as RDS subnets if desirable)
- (Optional) S3 VPC Endpoint configured within VPC
- (Optional) AWS Route53 Hosted Zone for TFE DNS record creation
- Chosen fully qualified domain name (FQDN) for TFE (_e.g._ `tfe.aws.example.com`)

#### Security groups

- This module will automatically create the necessary EKS-related security groups and attach them to the applicable resources when `create_eks_cluster` is `true`
- Identify CIDR range(s) that will need to access the TFE application
- (Optional) Identify CIDR range(s) of any monitoring/observability tools that will need to access (scrape) TFE metrics endpoints
- Identify CIDR range(s) that will need to access the TFE EKS cluster
- If your EKS cluster is private, your clients/workstations must be able to access the control plane via `kubectl` and `helm`
- Be familiar with the [TFE ingress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#ingress)
- Be familiar with the [TFE egress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress)
- If you are bringing your own EKS cluster (`create_eks_cluster` is `false`), then you must account for the following:
  - Allow `TCP/8443` (HTTPS) and `TCP/8080` (HTTP) ingress to EKS node group/TFE pods subnet from TFE load balancer subnet (for TFE application traffic)
  - Allow `TCP/8201` ingress between nodes in EKS node group/TFE pods subnet (for TFE embedded Vault internal cluster traffic)
  - (Optional) Allow `TCP/9091` (HTTPS) and/or `TCP/9090` (HTTP) ingress to EKS node group/TFE pods subnet from metrics collection tool (for scraping TFE metrics endpoints)
  - Allow `TCP/443` egress to Terraform endpoints listed [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress) from EKS node group/TFE pods subnet

### TLS certificates

- TLS certificate (_e.g._ `cert.pem`) and private key (_e.g._ `privkey.pem`) that matches your chosen fully qualified domain name (FQDN) for TFE
  - TLS certificate and private key must be in PEM format
  - Private key must **not** be password protected
- TLS certificate authority (CA) bundle (_e.g._ `ca_bundle.pem`) corresponding with the CA that issues your TFE TLS certificates
  - CA bundle must be in PEM format
  - You may include additional certificate chains corresponding to external systems that TFE will make outbound connections to (_e.g._ your self-hosted VCS, if its certificate was issued by a different CA than your TFE certificate).

>📝 Note: The TLS certificate and private key will be created as Kubernetes secrets during the [Post Steps](#post-steps).

### Secrets management

The following _bootstrap_ secrets stored in **AWS Secrets Manager** in order to bootstrap the TFE deployment:

 - **RDS (PostgreSQL) database password** - random characters stored as a plaintext secret; value must be between 8 and 128 characters long and must **not** contain '@', '\"', or '/' characters
 - **Redis password** - random characters stored as a plaintext secret; value must be between 16 and 128 characters long and must **not** contain '@', '\"', or '/' characters

### Compute (optional)

If you plan to create a new EKS cluster using this module (`create_eks_cluster` is `true`), then you may skip this section. Otherwise:

- EKS cluster with the following configurations:
  - EKS node group
  - EKS OIDC provider URL (used by module to create TFE IRSA)
  - EKS OIDC provider ARN (used by module to create TFE IRSA)
  - (Optional) AWS load balancer controller installed within EKS cluster (unless you plan to use a custom Kubernetes ingress controller load balancer)

### Log Forwarding (optional)

One of the following logging destinations:
  - AWS CloudWatch log group
  - AWS S3 bucket

---

## Usage

1. Create/configure/validate the applicable [prerequisites](#prerequisites).

2. Nested within the [examples](./examples/) directory are subdirectories containing ready-made Terraform configurations for example scenarios on how to call and deploy this module. To get started, choose the example scenario that most closely matches your requirements. You can customize your deployment later by adding additional module [inputs](#inputs) as you see fit (see the [Deployment-Customizations](./docs/deployment-customizations.md) doc for more details).

3. Copy all of the Terraform files from your example scenario of choice into a new destination directory to create your Terraform configuration that will manage your TFE deployment. This is a common directory structure for managing multiple TFE deployments:
   
    ```
    .
    └── environments
        ├── production
        │   ├── backend.tf
        │   ├── main.tf
        │   ├── outputs.tf
        │   ├── terraform.tfvars
        │   └── variables.tf
        └── sandbox
            ├── backend.tf
            ├── main.tf
            ├── outputs.tf
            ├── terraform.tfvars
            └── variables.tf
    ```
    >📝 Note: In this example, the user will have two separate TFE deployments; one for their `sandbox` environment, and one for their `production` environment. This is recommended, but not required.

4. (Optional) Uncomment and update the [S3 remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3) configuration provided in the `backend.tf` file with your own custom values. While this step is highly recommended, it is technically not required to use a remote backend config for your TFE deployment (if you are in a sandbox environment, for example).

5. Populate your own custom values into the `terraform.tfvars.example` file that was provided (in particular, values enclosed in the `<>` characters). Then, remove the `.example` file extension such that the file is now named `terraform.tfvars`.

6. Navigate to the directory of your newly created Terraform configuration for your TFE deployment, and run `terraform init`, `terraform plan`, and `terraform apply`.

**The TFE infrastructure resources have now been created. Next comes the application layer portion of the deployment (which we refer to as the Post Steps), which will involve interacting with your EKS cluster via `kubectl` and installing the TFE application via `helm`.**

## Post Steps

7. Authenticate to your EKS cluster: 
   
   ```shell
   aws eks --region <aws-region> update-kubeconfig --name <eks-cluster-name>
   ```

   >📝 Note: You can get the value of your EKS cluster name from the `eks_cluster_name` Terraform output if you created your EKS cluster via this module.

   >📝 Note: If you are running this command as an AWS identity *other than* the one that created the cluster, you will need to create additional [access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) similar to the ones created [here](./eks_cluster.tf#L44)

8. AWS recommends installing the AWS load balancer controller for EKS. If it is not already installed in your EKS cluster, install the AWS load balancer controller within the `kube-system` namespace via the Helm chart:
   
   Add the AWS `eks-charts` Helm chart repository:
   
   ```shell
   helm repo add eks https://aws.github.io/eks-charts
   ```
   
   Update your local repo to make sure that you have the most recent charts:
   
   ```shell
   helm repo update eks
   ```
   
   Install the AWS load balancer controller:
   
   ```shell
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=<eks-cluster-name> \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<aws-lb-controller-irsa-role-arn> \
    --set region=<aws-region> \
    --set vpcId=<vpc-id>
   ```

   >📝 Note: You can get the value of your AWS load balancer controller IRSA role ARN from the `aws_lb_controller_irsa_role_arn` Terraform output (if `create_aws_lb_controller_irsa` was `true`).

   >📝 Note: If you chose EKS Pod Identity, omit the `--set serviceAccount.annotations` option.


9. Create the Kubernetes namespace for TFE:
   
   ```sh
   kubectl create namespace tfe
   ```

   >📝 Note: You can name your TFE namespace something different than `tfe` if you prefer. If you do name it differently, be sure to update your value of the `tfe_kube_namespace` input variable accordingly.

10. Create the required secrets for your TFE deployment within your new Kubernetes namespace for TFE. There are several ways to do this, whether it be from the CLI via `kubectl`, or another method involving a third-party secrets helper/tool. See the [kubernetes-secrets](./docs/kubernetes-secrets.md) docs for details on the required secrets and how to create them.

11. This Terraform module will automatically generate a Helm overrides file within your Terraform working directory named `./helm/module_generated_helm_overrides.yaml`. This Helm overrides file contains values interpolated from some of the infrastructure resources that were created by Terraform in step 6. Within the Helm overrides file, update or validate the values for the remaining settings that are enclosed in the `<>` characters. You may also add any additional configuration settings into your Helm overrides file at this time (see the [helm-overrides](./docs/helm-overrides.md) doc for more details).

TODO: incorporate this `cat state.json|jq -r  '.resources[] | select(.name == "helm_overrides_values" and .type == "local_file") | .instances[0].attributes.content'|less`
    
12. Now that you have customized your `module_generated_helm_overrides.yaml` file, rename it to something more applicable to your deployment, such as `prod_tfe_overrides.yaml` (or whatever you prefer). Then, within your `terraform.tfvars` file, set the value of `create_helm_overrides_file` to `false`, as we no longer want the Terraform module to manage this file or generate a new one on a subsequent Terraform run.

13. Add the HashiCorp Helm chart repository:
   
    ```shell
    helm repo add hashicorp https://helm.releases.hashicorp.com
    ```

   >📝 Note: If you have already added the HashiCorp Helm registry, you should run `helm repo update hashicorp` to ensure you have the latest version.

14. Install the TFE application via `helm`:
   
    ```shell
    helm install terraform-enterprise hashicorp/terraform-enterprise --namespace <TFE_NAMESPACE> --values <TFE_OVERRIDES_FILE>
    ```

15. Verify the TFE pod(s) are starting successfully:
    
    View the events within the namespace:
    
    ```shell
    kubectl get events --namespace <TFE_NAMESPACE>
    ```
    
    View the pods within the namespace:
    
    ```shell
    kubectl get pods --namespace <TFE_NAMESPACE>
    ```

    View the logs from the pod:
    
    ```shell
    kubectl logs <TFE_POD_NAME> --namespace <TFE_NAMESPACE> -f
    ```

16. Create a DNS record for your TFE FQDN. The DNS record should resolve to your TFE load balancer, depending on how the load balancer was configured during your TFE deployment:
    
    - If you configured a Kubernetes service of type `LoadBalancer` (what the module-generated Helm overrides defaults to), the DNS record should resolve to the DNS name of your AWS network load balancer (NLB).
      
      ```shell
      kubectl get services --namespace <TFE_NAMESPACE>
      ```
    
    - If you configured a custom Kubernetes ingress (meaning you customized your Helm overrides during step 11), the DNS record should resolve to the IP address of your ingress controller load balancer.
      
      ```shell
      kubectl get ingress <INGRESS_NAME> --namespace <INGRESS_NAMESPACE>
      ```
    
    > 📝 Note: If you are creating your DNS record in Route53, AWS recommends creating an _alias_ record (if your TFE load balancer is an AWS-managed load balancer resource).
  
17. Verify the TFE application is ready:
      
    ```shell
    curl https://<TFE_FQDN>/_health_check
    ```

18. Follow the remaining steps [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/kubernetes/install#create-initial-admin-user) to finish the installation setup, which involves creating the **initial admin user**.

---

## Docs

Below are links to various docs related to the customization and management of your TFE deployment:

 - [Deployment customizations](./docs/deployment-customizations.md)
 - [Helm overrides](./docs/helm-overrides.md)
 - [TFE version upgrades](./docs/tfe-version-upgrades.md)
 - [TFE TLS certificate rotation](./docs/tfe-cert-rotation.md)
 - [TFE configuration settings](./docs/tfe-config-settings.md)
 - [TFE Kubernetes secrets](./docs-kubernetes-secrets.md)
 - [TFE IAM role for service accounts](./docs/tfe-irsa.md)

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.63 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.5.1 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | 4.0.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.63 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.5 |

## Resources

| Name | Type |
|------|------|
| [aws_db_parameter_group.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_eks_access_entry.tfe_cluster_creator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.tfe_cluster_creator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_addon.pod_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_cluster.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_pod_identity_association.aws_lb_controller_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_eks_pod_identity_association.tfe_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_elasticache_replication_group.redis_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_openid_connect_provider.tfe_eks_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.aws_load_balancer_controller_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.s3_crr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.tfe_eks_nodegroup_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.tfe_workload_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy_attachment.s3_crr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_role.aws_lb_controller_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.aws_lb_pi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.s3_crr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.tfe_eks_nodegroup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.tfe_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.tfe_pi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.aws_lb_pi_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.aws_load_balancer_controller_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_cluster_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_service_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_vpc_resource_controller_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfe_eks_nodegroup_cni_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfe_eks_nodegroup_container_registry_readonly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfe_eks_nodegroup_ebs_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfe_eks_nodegroup_worker_node_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfe_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfe_pi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.tfe_eks_nodegroup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_rds_cluster.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_parameter_group.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |
| [aws_rds_global_cluster.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster) | resource |
| [aws_s3_bucket.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_replication_configuration.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.tfe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.eks_cluster_allow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.rds_allow_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.redis_allow_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.tfe_eks_nodegroup_allow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.tfe_lb_allow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.eks_cluster_allow_all_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.eks_cluster_allow_ingress_nodegroup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_allow_ingress_from_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_allow_ingress_from_nodegroup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_allow_ingress_from_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.redis_allow_ingress_from_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.redis_allow_ingress_from_nodegroup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.redis_allow_ingress_from_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_10250_from_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_443_from_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_443_from_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_4443_from_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_6443_from_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_8443_from_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_9443_from_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_all_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_nodes_53_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_nodes_53_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_nodes_ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_tfe_http_from_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_tfe_https_from_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_tfe_metrics_http_from_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_eks_nodegroup_allow_tfe_metrics_https_from_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_lb_allow_all_egress_to_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_lb_allow_all_egress_to_nodegroup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_lb_allow_all_egress_to_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.tfe_lb_allow_ingress_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [local_file.helm_overrides_values](https://registry.terraform.io/providers/hashicorp/local/2.5.1/docs/resources/file) | resource |
| [aws_ami.tfe_eks_nodegroup_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.tfe_eks_nodegroup_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.aws_lb_controller_irsa_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_lb_pi_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_load_balancer_controller_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_cluster_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_crr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_crr_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_eks_nodegroup_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_eks_nodegroup_ebs_kms_cmk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_irsa_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_pi_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_workload_identity_combined](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_workload_identity_cost_estimation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_workload_identity_rds_kms_cmk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_workload_identity_redis_kms_cmk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_workload_identity_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfe_workload_identity_s3_kms_cmk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret_version.tfe_database_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.tfe_redis_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [tls_certificate.tfe_eks](https://registry.terraform.io/providers/hashicorp/tls/4.0.5/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_friendly_name_prefix"></a> [friendly\_name\_prefix](#input\_friendly\_name\_prefix) | Friendly name prefix used for uniquely naming all AWS resources for this deployment. Most commonly set to either an environment (e.g. 'sandbox', 'prod') a team name, or a project name. | `string` | n/a | yes |
| <a name="input_rds_subnet_ids"></a> [rds\_subnet\_ids](#input\_rds\_subnet\_ids) | List of subnet IDs to use for RDS database subnet group. | `list(string)` | n/a | yes |
| <a name="input_redis_subnet_ids"></a> [redis\_subnet\_ids](#input\_redis\_subnet\_ids) | List of subnet IDs to use for Redis cluster subnet group. | `list(string)` | n/a | yes |
| <a name="input_tfe_database_password_secret_arn"></a> [tfe\_database\_password\_secret\_arn](#input\_tfe\_database\_password\_secret\_arn) | ARN of AWS Secrets Manager secret for the TFE RDS Aurora (PostgreSQL) database password. | `string` | n/a | yes |
| <a name="input_tfe_fqdn"></a> [tfe\_fqdn](#input\_tfe\_fqdn) | Fully qualified domain name (FQDN) of TFE instance. This name should eventually resolve to the TFE load balancer DNS name or IP address and will be what clients use to access TFE. | `string` | n/a | yes |
| <a name="input_tfe_redis_password_secret_arn"></a> [tfe\_redis\_password\_secret\_arn](#input\_tfe\_redis\_password\_secret\_arn) | ARN of AWS Secrets Manager secret for the TFE Redis password. Value of secret must contain from 16 to 128 alphanumeric characters or symbols (excluding @, ", and /). | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of VPC where TFE will be deployed. | `string` | n/a | yes |
| <a name="input_aws_lb_controller_kube_namespace"></a> [aws\_lb\_controller\_kube\_namespace](#input\_aws\_lb\_controller\_kube\_namespace) | Name of Kubernetes namespace for AWS Load Balancer Controller service account (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html). | `string` | `"kube-system"` | no |
| <a name="input_aws_lb_controller_kube_svc_account"></a> [aws\_lb\_controller\_kube\_svc\_account](#input\_aws\_lb\_controller\_kube\_svc\_account) | Name of Kubernetes service account for AWS Load Balancer Controller (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html). | `string` | `"aws-load-balancer-controller"` | no |
| <a name="input_cidr_allow_egress_from_tfe_lb"></a> [cidr\_allow\_egress\_from\_tfe\_lb](#input\_cidr\_allow\_egress\_from\_tfe\_lb) | List of CIDR ranges to allow all outbound traffic from TFE load balancer. Only set this to your TFE pod CIDR ranges when an EKS cluster already exists outside of this module. | `list(string)` | `null` | no |
| <a name="input_cidr_allow_ingress_tfe_443"></a> [cidr\_allow\_ingress\_tfe\_443](#input\_cidr\_allow\_ingress\_tfe\_443) | List of CIDR ranges to allow TCP/443 inbound to TFE load balancer (load balancer is managed by Helm/K8s). | `list(string)` | `[]` | no |
| <a name="input_cidr_allow_ingress_tfe_metrics_http"></a> [cidr\_allow\_ingress\_tfe\_metrics\_http](#input\_cidr\_allow\_ingress\_tfe\_metrics\_http) | List of CIDR ranges to allow TCP/9090 or port specified in `tfe_metrics_http_port` (TFE HTTP metrics endpoint) inbound to TFE node group instances. | `list(string)` | `null` | no |
| <a name="input_cidr_allow_ingress_tfe_metrics_https"></a> [cidr\_allow\_ingress\_tfe\_metrics\_https](#input\_cidr\_allow\_ingress\_tfe\_metrics\_https) | List of CIDR ranges to allow TCP/9091 or port specified in `tfe_metrics_https_port` (TFE HTTPS metrics endpoint) inbound to TFE node group instances. | `list(string)` | `null` | no |
| <a name="input_cidr_allow_ingress_to_rds"></a> [cidr\_allow\_ingress\_to\_rds](#input\_cidr\_allow\_ingress\_to\_rds) | List of CIDR ranges to allow TCP/5432 (PostgreSQL) inbound to RDS cluster. | `list(string)` | `null` | no |
| <a name="input_cidr_allow_ingress_to_redis"></a> [cidr\_allow\_ingress\_to\_redis](#input\_cidr\_allow\_ingress\_to\_redis) | List of CIDR ranges to allow TCP/6379 (Redis) inbound to Redis cluster. | `list(string)` | `null` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Map of common tags for all taggable AWS resources. | `map(string)` | `{}` | no |
| <a name="input_create_aws_lb_controller_irsa"></a> [create\_aws\_lb\_controller\_irsa](#input\_create\_aws\_lb\_controller\_irsa) | Boolean to create AWS Load Balancer Controller IAM role and policies to enable EKS IAM role for service accounts (IRSA). | `bool` | `false` | no |
| <a name="input_create_aws_lb_controller_pod_identity"></a> [create\_aws\_lb\_controller\_pod\_identity](#input\_create\_aws\_lb\_controller\_pod\_identity) | Boolean to create AWS Load Balancer Controller IAM role and policies with the EKS addon to enable AWS LB Controller EKS IAM role using Pod Identity. | `bool` | `false` | no |
| <a name="input_create_eks_cluster"></a> [create\_eks\_cluster](#input\_create\_eks\_cluster) | Boolean to create new EKS cluster for TFE. | `bool` | `false` | no |
| <a name="input_create_eks_oidc_provider"></a> [create\_eks\_oidc\_provider](#input\_create\_eks\_oidc\_provider) | Boolean to create OIDC provider used to configure AWS IRSA. | `bool` | `false` | no |
| <a name="input_create_helm_overrides_file"></a> [create\_helm\_overrides\_file](#input\_create\_helm\_overrides\_file) | Boolean to generate a YAML file from template with Helm overrides values for TFE deployment. | `bool` | `true` | no |
| <a name="input_create_tfe_eks_irsa"></a> [create\_tfe\_eks\_irsa](#input\_create\_tfe\_eks\_irsa) | Boolean to create TFE IAM role and policies to enable TFE EKS IAM role for service accounts (IRSA). | `bool` | `false` | no |
| <a name="input_create_tfe_eks_pod_identity"></a> [create\_tfe\_eks\_pod\_identity](#input\_create\_tfe\_eks\_pod\_identity) | Boolean to create TFE IAM role and policies with the EKS addon to enable TFE EKS IAM role using Pod Identity. | `bool` | `false` | no |
| <a name="input_create_tfe_lb_security_group"></a> [create\_tfe\_lb\_security\_group](#input\_create\_tfe\_lb\_security\_group) | Boolean to create security group for TFE load balancer (load balancer is managed by Helm/K8s). | `bool` | `true` | no |
| <a name="input_eks_cluster_authentication_mode"></a> [eks\_cluster\_authentication\_mode](#input\_eks\_cluster\_authentication\_mode) | Authentication mode for access config of EKS cluster. | `string` | `"API_AND_CONFIG_MAP"` | no |
| <a name="input_eks_cluster_endpoint_public_access"></a> [eks\_cluster\_endpoint\_public\_access](#input\_eks\_cluster\_endpoint\_public\_access) | Boolean to enable public access to the EKS cluster endpoint. | `bool` | `false` | no |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | Name of created EKS cluster. Will be prefixed by `var.friendly_name_prefix` | `string` | `"tfe-eks-cluster"` | no |
| <a name="input_eks_cluster_public_access_cidrs"></a> [eks\_cluster\_public\_access\_cidrs](#input\_eks\_cluster\_public\_access\_cidrs) | List of CIDR blocks to allow public access to the EKS cluster endpoint. Only valid when `eks_cluster_endpoint_public_access` is `true`. | `list(string)` | `null` | no |
| <a name="input_eks_cluster_service_ipv4_cidr"></a> [eks\_cluster\_service\_ipv4\_cidr](#input\_eks\_cluster\_service\_ipv4\_cidr) | CIDR block for the EKS cluster Kubernetes service network. Must be a valid /16 CIDR block. EKS will auto-assign from either 10.100.0.0/16 or 172.20.0.0/16 CIDR blocks when `null`. | `string` | `null` | no |
| <a name="input_eks_nodegroup_ami_id"></a> [eks\_nodegroup\_ami\_id](#input\_eks\_nodegroup\_ami\_id) | ID of AMI to use for EKS node group. Required when `eks_nodegroup_ami_type` is `CUSTOM`. | `string` | `null` | no |
| <a name="input_eks_nodegroup_ami_type"></a> [eks\_nodegroup\_ami\_type](#input\_eks\_nodegroup\_ami\_type) | Type of AMI to use for EKS node group. Must be set to `CUSTOM` when `eks_nodegroup_ami_id` is not `null`. | `string` | `"AL2023_x86_64_STANDARD"` | no |
| <a name="input_eks_nodegroup_ebs_kms_key_arn"></a> [eks\_nodegroup\_ebs\_kms\_key\_arn](#input\_eks\_nodegroup\_ebs\_kms\_key\_arn) | ARN of KMS customer managed key (CMK) to encrypt EKS node group EBS volumes. | `string` | `null` | no |
| <a name="input_eks_nodegroup_instance_type"></a> [eks\_nodegroup\_instance\_type](#input\_eks\_nodegroup\_instance\_type) | Instance type for worker nodes within EKS node group. | `string` | `"m7i.xlarge"` | no |
| <a name="input_eks_nodegroup_name"></a> [eks\_nodegroup\_name](#input\_eks\_nodegroup\_name) | Name of EKS node group. | `string` | `"tfe-eks-nodegroup"` | no |
| <a name="input_eks_nodegroup_scaling_config"></a> [eks\_nodegroup\_scaling\_config](#input\_eks\_nodegroup\_scaling\_config) | Scaling configuration for EKS node group. | `map(number)` | <pre>{<br/>  "desired_size": 3,<br/>  "max_size": 3,<br/>  "min_size": 2<br/>}</pre> | no |
| <a name="input_eks_oidc_provider_arn"></a> [eks\_oidc\_provider\_arn](#input\_eks\_oidc\_provider\_arn) | ARN of existing OIDC provider for EKS cluster. Required when `create_eks_oidc_provider` is `false`. | `string` | `null` | no |
| <a name="input_eks_oidc_provider_url"></a> [eks\_oidc\_provider\_url](#input\_eks\_oidc\_provider\_url) | URL of existing OIDC provider for EKS cluster. Required when `create_eks_oidc_provider` is `false`. | `string` | `null` | no |
| <a name="input_eks_pod_identity_addon_version"></a> [eks\_pod\_identity\_addon\_version](#input\_eks\_pod\_identity\_addon\_version) | The version of the EKS Pod Identity Agent to use. Defaults to latest. | `string` | `null` | no |
| <a name="input_eks_subnet_ids"></a> [eks\_subnet\_ids](#input\_eks\_subnet\_ids) | List of subnet IDs to use for EKS cluster. | `list(string)` | `null` | no |
| <a name="input_existing_eks_cluster_name"></a> [existing\_eks\_cluster\_name](#input\_existing\_eks\_cluster\_name) | Name of existing EKS cluster, which will receive Pod Identity addon. Required when `create_eks_cluster` is `false` and `create_tfe_eks_pod_identity` is true. | `string` | `null` | no |
| <a name="input_force_destroy_s3_bucket"></a> [force\_destroy\_s3\_bucket](#input\_force\_destroy\_s3\_bucket) | ability to detroy the s3 bucket if needed | `bool` | `false` | no |
| <a name="input_is_secondary_region"></a> [is\_secondary\_region](#input\_is\_secondary\_region) | Boolean indicating whether this TFE deployment is in the 'primary' region or 'secondary' region. | `bool` | `false` | no |
| <a name="input_rds_apply_immediately"></a> [rds\_apply\_immediately](#input\_rds\_apply\_immediately) | Boolean to apply changes immediately to RDS cluster instance. | `bool` | `true` | no |
| <a name="input_rds_aurora_engine_mode"></a> [rds\_aurora\_engine\_mode](#input\_rds\_aurora\_engine\_mode) | RDS Aurora database engine mode. | `string` | `"provisioned"` | no |
| <a name="input_rds_aurora_engine_version"></a> [rds\_aurora\_engine\_version](#input\_rds\_aurora\_engine\_version) | Engine version of RDS Aurora PostgreSQL. | `number` | `16.2` | no |
| <a name="input_rds_aurora_instance_class"></a> [rds\_aurora\_instance\_class](#input\_rds\_aurora\_instance\_class) | Instance class of Aurora PostgreSQL database. | `string` | `"db.r6i.xlarge"` | no |
| <a name="input_rds_aurora_replica_count"></a> [rds\_aurora\_replica\_count](#input\_rds\_aurora\_replica\_count) | Number of replica (reader) cluster instances to create within the RDS Aurora database cluster (within the same region). | `number` | `1` | no |
| <a name="input_rds_availability_zones"></a> [rds\_availability\_zones](#input\_rds\_availability\_zones) | List of AWS availability zones to spread Aurora database cluster instances across. Leave as `null` and RDS will automatically assign 3 availability zones. | `list(string)` | `null` | no |
| <a name="input_rds_backup_retention_period"></a> [rds\_backup\_retention\_period](#input\_rds\_backup\_retention\_period) | The number of days to retain backups for. Must be between 0 and 35. Must be greater than 0 if the database cluster is used as a source of a read replica cluster. | `number` | `35` | no |
| <a name="input_rds_deletion_protection"></a> [rds\_deletion\_protection](#input\_rds\_deletion\_protection) | Boolean to enable deletion protection for RDS global cluster. | `bool` | `false` | no |
| <a name="input_rds_force_destroy"></a> [rds\_force\_destroy](#input\_rds\_force\_destroy) | Boolean to enable the removal of RDS database cluster members from RDS global cluster on destroy. | `bool` | `false` | no |
| <a name="input_rds_global_cluster_id"></a> [rds\_global\_cluster\_id](#input\_rds\_global\_cluster\_id) | ID of RDS global cluster. Only required only when `is_secondary_region` is `true`, otherwise leave as `null`. | `string` | `null` | no |
| <a name="input_rds_kms_key_arn"></a> [rds\_kms\_key\_arn](#input\_rds\_kms\_key\_arn) | ARN of KMS customer managed key (CMK) to encrypt TFE RDS cluster. | `string` | `null` | no |
| <a name="input_rds_parameter_group_family"></a> [rds\_parameter\_group\_family](#input\_rds\_parameter\_group\_family) | Family of Aurora PostgreSQL database parameter group. | `string` | `"aurora-postgresql16"` | no |
| <a name="input_rds_performance_insights_enabled"></a> [rds\_performance\_insights\_enabled](#input\_rds\_performance\_insights\_enabled) | Boolean to enable performance insights for RDS cluster instance(s). | `bool` | `true` | no |
| <a name="input_rds_performance_insights_retention_period"></a> [rds\_performance\_insights\_retention\_period](#input\_rds\_performance\_insights\_retention\_period) | Number of days to retain RDS performance insights data. Must be between 7 and 731. | `number` | `7` | no |
| <a name="input_rds_preferred_backup_window"></a> [rds\_preferred\_backup\_window](#input\_rds\_preferred\_backup\_window) | Daily time range (UTC) for RDS backup to occur. Must not overlap with `rds_preferred_maintenance_window`. | `string` | `"04:00-04:30"` | no |
| <a name="input_rds_preferred_maintenance_window"></a> [rds\_preferred\_maintenance\_window](#input\_rds\_preferred\_maintenance\_window) | Window (UTC) to perform RDS database maintenance. Must not overlap with `rds_preferred_backup_window`. | `string` | `"Sun:08:00-Sun:09:00"` | no |
| <a name="input_rds_replication_source_identifier"></a> [rds\_replication\_source\_identifier](#input\_rds\_replication\_source\_identifier) | ARN of source RDS cluster or cluster instance if this cluster is to be created as a read replica. Only required when `is_secondary_region` is `true`, otherwise leave as `null`. | `string` | `null` | no |
| <a name="input_rds_skip_final_snapshot"></a> [rds\_skip\_final\_snapshot](#input\_rds\_skip\_final\_snapshot) | Boolean to enable RDS to take a final database snapshot before destroying. | `bool` | `false` | no |
| <a name="input_rds_source_region"></a> [rds\_source\_region](#input\_rds\_source\_region) | Source region for RDS cross-region replication. Only required when `is_secondary_region` is `true`, otherwise leave as `null`. | `string` | `null` | no |
| <a name="input_rds_storage_encrypted"></a> [rds\_storage\_encrypted](#input\_rds\_storage\_encrypted) | Boolean to encrypt RDS storage. An AWS managed key will be used when `true` unless a value is also specified for `rds_kms_key_arn`. | `bool` | `true` | no |
| <a name="input_redis_apply_immediately"></a> [redis\_apply\_immediately](#input\_redis\_apply\_immediately) | Boolean to apply changes immediately to Redis cluster. | `bool` | `true` | no |
| <a name="input_redis_at_rest_encryption_enabled"></a> [redis\_at\_rest\_encryption\_enabled](#input\_redis\_at\_rest\_encryption\_enabled) | Boolean to enable encryption at rest on Redis cluster. An AWS managed key will be used when `true` unless a value is also specified for `redis_kms_key_arn`. | `bool` | `true` | no |
| <a name="input_redis_auto_minor_version_upgrade"></a> [redis\_auto\_minor\_version\_upgrade](#input\_redis\_auto\_minor\_version\_upgrade) | Boolean to enable automatic minor version upgrades for Redis cluster. | `bool` | `true` | no |
| <a name="input_redis_automatic_failover_enabled"></a> [redis\_automatic\_failover\_enabled](#input\_redis\_automatic\_failover\_enabled) | Boolean for deploying Redis nodes in multiple availability zones and enabling automatic failover. | `bool` | `true` | no |
| <a name="input_redis_engine_version"></a> [redis\_engine\_version](#input\_redis\_engine\_version) | Redis version number. | `string` | `"7.1"` | no |
| <a name="input_redis_kms_key_arn"></a> [redis\_kms\_key\_arn](#input\_redis\_kms\_key\_arn) | ARN of KMS customer managed key (CMK) to encrypt Redis cluster with. | `string` | `null` | no |
| <a name="input_redis_multi_az_enabled"></a> [redis\_multi\_az\_enabled](#input\_redis\_multi\_az\_enabled) | Boolean to create Redis nodes across multiple availability zones. If `true`, `redis_automatic_failover_enabled` must also be `true`, and more than one subnet must be specified within `redis_subnet_ids`. | `bool` | `true` | no |
| <a name="input_redis_node_type"></a> [redis\_node\_type](#input\_redis\_node\_type) | Type (size) of Redis node from a compute, memory, and network throughput standpoint. | `string` | `"cache.m5.large"` | no |
| <a name="input_redis_parameter_group_name"></a> [redis\_parameter\_group\_name](#input\_redis\_parameter\_group\_name) | Name of parameter group to associate with Redis cluster. | `string` | `"default.redis7"` | no |
| <a name="input_redis_port"></a> [redis\_port](#input\_redis\_port) | Port number the Redis nodes will accept connections on. | `number` | `6379` | no |
| <a name="input_redis_transit_encryption_enabled"></a> [redis\_transit\_encryption\_enabled](#input\_redis\_transit\_encryption\_enabled) | Boolean to enable TLS encryption between TFE and the Redis cluster. | `bool` | `true` | no |
| <a name="input_role_permissions_boundary"></a> [role\_permissions\_boundary](#input\_role\_permissions\_boundary) | ARN of the IAM role permissions boundary to be attached. | `string` | `""` | no |
| <a name="input_s3_destination_bucket_arn"></a> [s3\_destination\_bucket\_arn](#input\_s3\_destination\_bucket\_arn) | ARN of destination S3 bucket for cross-region replication configuration. Bucket should already exist in secondary region. Required when `s3_enable_bucket_replication` is `true`. | `string` | `""` | no |
| <a name="input_s3_destination_bucket_kms_key_arn"></a> [s3\_destination\_bucket\_kms\_key\_arn](#input\_s3\_destination\_bucket\_kms\_key\_arn) | ARN of KMS key of destination S3 bucket for cross-region replication configuration if it is encrypted with a customer managed key (CMK). | `string` | `null` | no |
| <a name="input_s3_enable_bucket_replication"></a> [s3\_enable\_bucket\_replication](#input\_s3\_enable\_bucket\_replication) | Boolean to enable cross-region replication for TFE S3 bucket. Do not enable when `is_secondary_region` is `true`. An `s3_destination_bucket_arn` is also required when `true`. | `bool` | `false` | no |
| <a name="input_s3_kms_key_arn"></a> [s3\_kms\_key\_arn](#input\_s3\_kms\_key\_arn) | ARN of KMS customer managed key (CMK) to encrypt TFE S3 bucket with. | `string` | `null` | no |
| <a name="input_sg_allow_egress_from_tfe_lb"></a> [sg\_allow\_egress\_from\_tfe\_lb](#input\_sg\_allow\_egress\_from\_tfe\_lb) | Security group ID of EKS node group to allow all egress traffic from TFE load balancer. Only set this to your TFE pod security group ID when an EKS cluster already exists outside of this module. | `string` | `null` | no |
| <a name="input_sg_allow_ingress_to_rds"></a> [sg\_allow\_ingress\_to\_rds](#input\_sg\_allow\_ingress\_to\_rds) | Security group ID to allow TCP/5432 (PostgreSQL) inbound to RDS cluster. | `string` | `null` | no |
| <a name="input_sg_allow_ingress_to_redis"></a> [sg\_allow\_ingress\_to\_redis](#input\_sg\_allow\_ingress\_to\_redis) | Security group ID to allow TCP/6379 (Redis) inbound to Redis cluster. | `string` | `null` | no |
| <a name="input_tfe_cost_estimation_iam_enabled"></a> [tfe\_cost\_estimation\_iam\_enabled](#input\_tfe\_cost\_estimation\_iam\_enabled) | Boolean to add AWS pricing actions to TFE IAM role for service account (IRSA). Only implemented when `create_tfe_eks_irsa` is `true`. | `string` | `true` | no |
| <a name="input_tfe_database_name"></a> [tfe\_database\_name](#input\_tfe\_database\_name) | Name of TFE database to create within RDS global cluster. | `string` | `"tfe"` | no |
| <a name="input_tfe_database_parameters"></a> [tfe\_database\_parameters](#input\_tfe\_database\_parameters) | PostgreSQL server parameters for the connection URI. Used to configure the PostgreSQL connection. | `string` | `"sslmode=require"` | no |
| <a name="input_tfe_database_user"></a> [tfe\_database\_user](#input\_tfe\_database\_user) | Username for TFE RDS database cluster. | `string` | `"tfe"` | no |
| <a name="input_tfe_http_port"></a> [tfe\_http\_port](#input\_tfe\_http\_port) | HTTP port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `8080` | no |
| <a name="input_tfe_https_port"></a> [tfe\_https\_port](#input\_tfe\_https\_port) | HTTPS port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `8443` | no |
| <a name="input_tfe_kube_namespace"></a> [tfe\_kube\_namespace](#input\_tfe\_kube\_namespace) | Name of Kubernetes namespace for TFE service account (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html). | `string` | `"tfe"` | no |
| <a name="input_tfe_kube_svc_account"></a> [tfe\_kube\_svc\_account](#input\_tfe\_kube\_svc\_account) | Name of Kubernetes service account for TFE (to be created by Helm chart). Used to configure EKS [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html). | `string` | `"tfe"` | no |
| <a name="input_tfe_metrics_http_port"></a> [tfe\_metrics\_http\_port](#input\_tfe\_metrics\_http\_port) | HTTP port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `9090` | no |
| <a name="input_tfe_metrics_https_port"></a> [tfe\_metrics\_https\_port](#input\_tfe\_metrics\_https\_port) | HTTPS port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `9091` | no |
| <a name="input_tfe_object_storage_s3_access_key_id"></a> [tfe\_object\_storage\_s3\_access\_key\_id](#input\_tfe\_object\_storage\_s3\_access\_key\_id) | Access key ID for S3 bucket. Required when `tfe_object_storage_s3_use_instance_profile` is `false`. | `string` | `null` | no |
| <a name="input_tfe_object_storage_s3_secret_access_key"></a> [tfe\_object\_storage\_s3\_secret\_access\_key](#input\_tfe\_object\_storage\_s3\_secret\_access\_key) | Secret access key for S3 bucket. Required when `tfe_object_storage_s3_use_instance_profile` is `false`. | `string` | `null` | no |
| <a name="input_tfe_object_storage_s3_use_instance_profile"></a> [tfe\_object\_storage\_s3\_use\_instance\_profile](#input\_tfe\_object\_storage\_s3\_use\_instance\_profile) | Boolean to use instance profile for S3 bucket access. If `false`, `tfe_object_storage_s3_access_key_id` and `tfe_object_storage_s3_secret_access_key` are required. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_lb_controller_irsa_role_arn"></a> [aws\_lb\_controller\_irsa\_role\_arn](#output\_aws\_lb\_controller\_irsa\_role\_arn) | ARN of IAM role for AWS Load Balancer Controller IRSA. |
| <a name="output_eks_cluster_name"></a> [eks\_cluster\_name](#output\_eks\_cluster\_name) | Name of TFE EKS cluster. |
| <a name="output_eks_cluster_security_group_id"></a> [eks\_cluster\_security\_group\_id](#output\_eks\_cluster\_security\_group\_id) | ID of the default cluster security group created by EKS. |
| <a name="output_elasticache_replication_group_arn"></a> [elasticache\_replication\_group\_arn](#output\_elasticache\_replication\_group\_arn) | ARN of ElastiCache Replication Group (Redis) cluster. |
| <a name="output_elasticache_replication_group_id"></a> [elasticache\_replication\_group\_id](#output\_elasticache\_replication\_group\_id) | ID of ElastiCache Replication Group (Redis) cluster. |
| <a name="output_elasticache_replication_group_primary_endpoint_address"></a> [elasticache\_replication\_group\_primary\_endpoint\_address](#output\_elasticache\_replication\_group\_primary\_endpoint\_address) | Primary endpoint address of ElastiCache Replication Group (Redis) cluster. |
| <a name="output_rds_aurora_cluster_arn"></a> [rds\_aurora\_cluster\_arn](#output\_rds\_aurora\_cluster\_arn) | ARN of RDS Aurora database cluster. |
| <a name="output_rds_aurora_cluster_endpoint"></a> [rds\_aurora\_cluster\_endpoint](#output\_rds\_aurora\_cluster\_endpoint) | RDS Aurora database cluster endpoint. |
| <a name="output_rds_aurora_cluster_members"></a> [rds\_aurora\_cluster\_members](#output\_rds\_aurora\_cluster\_members) | List of instances that are part of this RDS Aurora database cluster. |
| <a name="output_rds_aurora_global_cluster_id"></a> [rds\_aurora\_global\_cluster\_id](#output\_rds\_aurora\_global\_cluster\_id) | RDS Aurora global database cluster identifier. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of TFE S3 bucket. |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of TFE S3 bucket. |
| <a name="output_s3_crr_iam_role_arn"></a> [s3\_crr\_iam\_role\_arn](#output\_s3\_crr\_iam\_role\_arn) | ARN of S3 cross-region replication IAM role. |
| <a name="output_tfe_database_host"></a> [tfe\_database\_host](#output\_tfe\_database\_host) | PostgreSQL server endpoint in the format that TFE will connect to. |
| <a name="output_tfe_database_password"></a> [tfe\_database\_password](#output\_tfe\_database\_password) | TFE PostgreSQL database password. |
| <a name="output_tfe_database_password_base64"></a> [tfe\_database\_password\_base64](#output\_tfe\_database\_password\_base64) | Base64-encoded TFE PostgreSQL database password. |
| <a name="output_tfe_irsa_role_arn"></a> [tfe\_irsa\_role\_arn](#output\_tfe\_irsa\_role\_arn) | ARN of IAM role for TFE EKS IRSA. |
| <a name="output_tfe_lb_security_group_id"></a> [tfe\_lb\_security\_group\_id](#output\_tfe\_lb\_security\_group\_id) | ID of security group for TFE load balancer. |
| <a name="output_tfe_redis_password"></a> [tfe\_redis\_password](#output\_tfe\_redis\_password) | TFE Redis password. |
| <a name="output_tfe_redis_password_base64"></a> [tfe\_redis\_password\_base64](#output\_tfe\_redis\_password\_base64) | Base64-encoded TFE Redis password. |
| <a name="output_tfe_url"></a> [tfe\_url](#output\_tfe\_url) | URL to access TFE application based on value of `tfe_fqdn` input. |
<!-- END_TF_DOCS -->
