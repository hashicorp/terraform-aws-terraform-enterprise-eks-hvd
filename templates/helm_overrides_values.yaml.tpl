replicaCount: 1
tls:
  certificateSecret: <tfe-certs>
  caCertData: |
    <base64-encoded TFE CA bundle>

image:
 repository: images.releases.hashicorp.com
 name: hashicorp/terraform-enterprise
 tag: <v202503-1> # refer to https://developer.hashicorp.com/terraform/enterprise/releases

# TODO: reconcile for EKS PI
%{ if tfe_eks_irsa_arn != "" ~}
serviceAccount:
  enabled: true
  name: ${tfe_kube_svc_account}
  annotations:
    eks.amazonaws.com/role-arn: ${tfe_eks_irsa_arn}
%{ endif ~}

tfe:
  privateHttpPort: ${tfe_http_port}
  privateHttpsPort: ${tfe_https_port}
  metrics:
    enable: <true>
    httpPort: ${tfe_metrics_http_port}
    httpsPort: ${tfe_metrics_https_port}

service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internal" # for an external LB, set to "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-subnets: "<list, of, lb_subnet_ids>" # TFE load balancer subnets, no brackets in annotation list
    service.beta.kubernetes.io/aws-load-balancer-security-groups: ${tfe_lb_security_groups}
  type: LoadBalancer
  port: 443

env:
  secretRefs:
    - name: <tfe-secrets>
  
  variables:
    # TFE configuration settings
    TFE_HOSTNAME: ${tfe_hostname}

    # Database settings
    TFE_DATABASE_HOST: ${tfe_database_host}
    TFE_DATABASE_NAME: ${tfe_database_name}
    TFE_DATABASE_USER: ${tfe_database_user}
    TFE_DATABASE_PARAMETERS: ${tfe_database_parameters}

    # Object storage settings
    TFE_OBJECT_STORAGE_TYPE: ${tfe_object_storage_type}
    TFE_OBJECT_STORAGE_S3_BUCKET: ${tfe_object_storage_s3_bucket}
    TFE_OBJECT_STORAGE_S3_REGION: ${tfe_object_storage_s3_region}
%{ if tfe_object_storage_s3_endpoint != "" ~}    
    TFE_OBJECT_STORAGE_S3_ENDPOINT: ${tfe_object_storage_s3_endpoint}
%{ endif ~}
    TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE: ${tfe_object_storage_s3_use_instance_profile}
%{ if !tfe_object_storage_s3_use_instance_profile ~}
    TFE_OBJECT_STORAGE_S3_ACCESS_KEY_ID: ${tfe_object_storage_s3_access_key_id}
    TFE_OBJECT_STORAGE_S3_SECRET_ACCESS_KEY: ${tfe_object_storage_s3_secret_access_key}
%{ endif ~}
    TFE_OBJECT_STORAGE_S3_SERVER_SIDE_ENCRYPTION: ${tfe_object_storage_s3_server_side_encryption}
    TFE_OBJECT_STORAGE_S3_SERVER_SIDE_ENCRYPTION_KMS_KEY_ID: ${tfe_object_storage_s3_server_side_encryption_kms_key_id}

    # Redis settings
    TFE_REDIS_HOST: ${tfe_redis_host}
    TFE_REDIS_USE_AUTH: ${tfe_redis_use_auth}
    TFE_REDIS_USE_TLS: ${tfe_redis_use_tls}
    