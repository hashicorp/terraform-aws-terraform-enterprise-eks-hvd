# TFE certificate rotation

If your TFE TLS certificates are set to expire, you will need to rotate new ones into your Kubernetes secret managing your TFE TLS certificates prior to the expiration date.

## Procedure

1. Generate your new TFE TLS certificates from your Certificate Authority. Reference the *TLS Certificate and Private Key* section of the `docs/kubernetes-secrets.md` doc for specific details on which files and format are required.

1. Run the following command to update your existing Kubernetes secret for your TFE TLS certificates:

    ```sh
    kubectl create secret tls <tfe-certs> \
      --namespace=<TFE_NAMESPACE> \
      --cert=/path/to/your/new/tls.crt \
      --key=/path/to/your/new/tls.key --dry-run=client -o yaml | kubectl apply -f -
    ```

1. The next time your TFE pod(s) are rescheduled or restarted, they should come up with the new TLS certificates.
