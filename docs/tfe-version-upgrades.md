# TFE Version Upgrades

TFE follows a monthly release cadence. See the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) page for full details on the releases. The process for upgrading your TFE instance to a new version involves updating the value of `image.tag` within your Helm overrides file, and then running `helm upgrade` on your TFE release during a maintenance window.

## Procedure

1. Determine your desired version of TFE from the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) page. The value that you need will be in the **Version** column of the table that is displayed. Ensure you are on the **Kubernetes** tab of the table. When determing your target TFE version to upgrade to, be sure to check if there are any required releases in between your current and target version (denoted by a `*` character in the table).

2. During a maintenance window, connect to your TFE pod(s) and gracefully drain the node(s), preventing them from being able to execute any new Terraform runs until the pod(s) are rescheduled or restarted.
   
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

3. Generate a backup of your RDS Aurora PostgreSQL database.

4. Update the value of `image.tag` to your target version within your Helm overrides file.

   ```yaml
   image:
     tag: v202407-1
   ```

5. Run `helm upgrade` on your TFE release.

   ```sh
   helm upgrade terraform-enterprise hashicorp/terraform-enterprise --namespace <TFE_NAMESPACE> --values /path/to/tfe_helm_overrides.yaml
   ```

6. Delete the existing TFE pod(s), allowing Kubernetes to reschedule new ones.