# TFE Configuration Settings

The TFE configuration settings for your deployment are managed within your Helm overrides file. If you would like to add or modify a configuration setting(s) within your deployment, you must edit your Helm overrides file, specifically the `env.variables` section, and then subsequently run `helm upgrade` on your TFE release. See the [TFE configuration reference](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration) doc for details on all of the available settings.

>📝 Note: The steps below only pertain to the TFE configuration settings that are not configured as secrets. The sensitive configuration settings and their values were created as Kubernetes secrets during the initial TFE deployment (see the [kubernetes-secrets](./kubernetes-secrets.md) doc for more details on which settings are considered sensitive).

## Procedure

1. Identity which TFE configuration setting you would like to add or modify by referencing the [TFE configuration reference](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration) doc.
   
2. Update the values in your Helm overrides file accordingly.
   
   ```yaml
   ...
   env:
     variables:
       NEW_SETTING: <new-value>
   ```

3. During a maintenance window, connect to your TFE pod(s) and gracefully drain the node(s), preventing them from being able to execute any new Terraform runs until the pod(s) are rescheduled or restarted.
   
   Access the TFE command line (`tfectl`) within your TFE pod(s):
   
   ```sh
   kubectl exec --namespace <TFE_NAMESPACE> -it <TFE_POD_NAME> -- bash
   ```

   Gracefully stop work on all nodes:
   
   ```sh
   tfectl node drain --all
   ```

   For more details on the above commands, see the following documentation:
    - [Access the TFE command line](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/admin/admin-cli/cli-access)
    - [Gracefully stop work on a node](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/admin/admin-cli/admin-cli#gracefully-stop-work-on-a-node)

4. Run `helm upgrade` to create a new TFE release.
   
   ```sh
   helm upgrade terraform-enterprise hashicorp/terraform-enterprise --namespace <TFE_NAMESPACE> --values </path/to/tfe_helm_overrides.yaml>
   ```

5. Delete the existing TFE pod(s), allowing Kubernetes to reschedule new ones.