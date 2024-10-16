# Kubernetes secrets for TFE

## Secret types

There are three different types of secrets required for a TFE deployment:

1. Image pull secret for Kubernetes to authenticate to container registry where TFE image is hosted
2. TFE configuration settings secrets (key/value pairs)
3. TLS certficate and private key (in PEM format)

### 1. Image pull secret

Username: `terraform`
Password: your HashiCorp Terraform Enterprise license file (_e.g._ `terraform.hclic`)

>📝 Note: if you prefer to host the TFE container image somewhere custom, then these values would change accordingly.

### 2. TFE configuration settings secrets

- `TFE_LICENSE` - your HashiCorp Terraform Enterprise license file (_e.g._ `terraform.hclic`)
- `TFE_ENCRYPTION_PASSWORD` - generate this yourself; this is used to encrypt and decrypt TFE's embedded Vault root token and unseal key.
- `TFE_DATABASE_PASSWORD` - obtain from Terraform module output named `tfe_database_password` or `tfe_database_password_base64` depending on the format you need.
- `TFE_REDIS_PASSWORD` - obtain from Terraform module output named `tfe_redis_password` or `tfe_redis_password_base64` depending on the format you need.

>📝 Note: to show the value of a sensitive Terraform output, run `terraform output <output-name>`.

### 3. TLS certificate and private key

The TLS certificate and private key must correspond with the chosen FQDN of your TFE instance (_e.g._ `tfe.aws.example.com`). You should have two separate files; one for the certificate (_e.g._ `cert.pem`) and one for the private key (_e.g._ `key.pem`). They must be in PEM format.

## Creating secrets

There are many ways to create secrets in Kubernetes. **If you already have an existing method, tool, or process to do so, then we recommend using that that**. If not, follow the steps below to create your Kubernetes secrets for your TFE deployment.

### Using kubectl

This method involves creating the secrets directly from the CLI via `kubectl`.

#### Image pull secret

```sh
kubectl create secret docker-registry terraform-enterprise \
  --namespace <TFE_NAMESPACE> \
  --docker-server=images.releases.hashicorp.com \
  --docker-username=terraform \
  --docker-password=$(cat /path/to/tfe_license.hclic)
```

>📝 Note: if you are hosting the TFE container image in your own registry, then you would need to update the arguments values accordingly.

#### TFE configuration settings secrets

```sh
kubectl create secret generic tfe-secrets \
  --namespace=<TFE_NAMESPACE> \
  --from-file=TFE_LICENSE=/path/to/tfe_license.hclic \
  --from-literal=TFE_ENCRYPTION_PASSWORD=<TFE_ENCRYPTION_PASSWORD> \
  --from-literal=TFE_DATABASE_PASSWORD=<TFE_DATABASE_PASSWORD> \
  --from-literal=TFE_REDIS_PASSWORD=<TFE_REDIS_PASSWORD>
```

>📝 Note: Do not base64-encode these values; the `kubectl` command will do it for you.

#### TLS certificate and private key

```sh
kubectl create secret tls tfe-certs \
  --namespace=<TFE_NAMESPACE> \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

## Appendix

For visual representation purposes only, here is a Kubernetes manifest of the required secrets for a TFE deployment (the secrets that were created in the previous step).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: terraform-enterprise
  namespace: <TFE_NAMESPACE>
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: |
    <base64-encoded Docker config JSON>
---
apiVersion: v1
kind: Secret
metadata:
  name: <tfe-secrets>
  namespace: <TFE_NAMESPACE>
type: Opaque
data:
  TFE_LICENSE: <base64-encoded TFE license>
  TFE_ENCRYPTION_PASSWORD: <base64-encoded TFE encryption password>
  TFE_DATABASE_PASSWORD: <base64-encoded TFE PostgreSQL database password>
  TFE_REDIS_PASSWORD: <base64-encoded TFE Redis password>
---
apiVersion: v1
kind: Secret
metadata:
  name: <tfe-certs>
  namespace: <TFE_NAMESPACE>
type: kubernetes.io/tls
data:
  tls.crt: |
    <base64-encoded TFE certificate>
  tls.key: |
    <base64-encoded TFE private key>
```
