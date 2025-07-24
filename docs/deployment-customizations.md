# Deployment customizations

This doc contains various deployment customizations as it relates to creating your TFE infrastructure, and their corresponding module input variables that you may additionally set to meet your own requirements where the module default values do not suffice. That said, all of the module input variables on this page are optional.

<!--
## EKS

placeholder
-->

## KMS

If you require the use of a customer-managed key(s) (CMK) to encrypt your AWS resources, the following module input variables may be set:

```hcl
rds_kms_key_arn               = "<rds-kms-key-arn>"
s3_kms_key_arn                = "<s3-kms-key-arn>"
redis_kms_key_arn             = "<redis-kms-key-arn>"
eks_nodegroup_ebs_kms_key_arn = "<ebs-kms-key-arn>"
```
