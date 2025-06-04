mock_provider "aws" {
  mock_data "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456780000:policy/DemoUser"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = { "account_id" : "123456780000", "arn" : "arn:aws:sts::123456780000:assumed-role/vault-assumed-role-credentials-demo/terraform-run-GAcgnMy9UDj8JKGg", "id" : "123456780000", "user_id" : "AROAYS2NVTPC2D6EI6FHV:terraform-run-GAcgnMy9UDj8JKGg" }
  }
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456780000:role/role"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EksClusterAssumeRole",
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    }
  }
  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "vie6umei5uJ4Li9c"
    }
  }
}

variables {
  create_eks_cluster               = true
  create_tfe_eks_pod_identity      = true
  friendly_name_prefix             = "primary"
  tfe_fqdn                         = "tfe.tyler-durden.sbx.hashidemos.io"
  vpc_id                           = "vpc-1234"
  rds_subnet_ids                   = ["subnet-1234", "subnet-56789"]
  tfe_database_password_secret_arn = "arn:aws:secretsmanager:us-west-2:12345678:secret:primary-tfe-database-password-a69a-cHdzKn"
  tfe_redis_password_secret_arn    = "arn:aws:secretsmanager:us-west-2:12345678:secret:primary-tfe-redis-password-a69a-cHdzKn"
  redis_subnet_ids                 = ["subnet-1234", "subnet-56789"]
  eks_subnet_ids                   = ["subnet-1234", "subnet-56789"]
}

run "irsa_requires_oidc_provider" {
  command = plan

  variables {
    create_tfe_eks_pod_identity = false
    create_eks_oidc_provider    = false
    create_tfe_eks_irsa         = true
    eks_oidc_provider_arn       = null
    eks_oidc_provider_url       = null
  }

  expect_failures = [
    var.eks_oidc_provider_arn
  ]
}

run "pod_identity_conflicts_with_irsa" {
  command = plan

  variables {
    create_tfe_eks_irsa      = true
    create_eks_oidc_provider = true
  }

  expect_failures = [
    var.create_tfe_eks_irsa,
    # var.create_tfe_eks_pod_identity
  ]
}

run "pod_identity_option_creates_addon" {
  command = plan

  assert {
    condition     = length(aws_eks_addon.pod_identity) == 1
    error_message = "Pod Identity addon not created when expected."
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.tfe_association) == 1
    error_message = "Pod Identity association for TFE not created when expected."
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.aws_lb_controller_association) == 1
    error_message = "Pod Identity association for LB controller not created when expected."
  }

  assert {
    condition     = length(aws_iam_role.tfe_pi) == 1
    error_message = "IAM Role for Pod Identity not created when expected."
  }
}

run "no_pod_identity_option_creates_addon" {
  command = plan

  variables {
    create_tfe_eks_pod_identity = false
  }

  assert {
    condition     = length(aws_eks_addon.pod_identity) == 0
    error_message = "Pod Identity addon created when not expected."
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.tfe_association) == 0
    error_message = "Pod Identity association for TFE created when not expected."
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.aws_lb_controller_association) == 0
    error_message = "Pod Identity association for LB controller when not expected."
  }

  assert {
    condition     = length(aws_iam_role.tfe_pi) == 0
    error_message = "IAM Role for Pod Identity created when not expected."
  }
}

# run "aws_false_success" {
#   command = plan

#   variables {
#     configure_aws = false
#   }

#   assert {
#     condition     = length(vault_aws_secret_backend.aws) == 0
#     error_message = "AWS Secret Backend created when not expected"
#   }
# }

# run "aws_true_success" {
#   command = plan

#   variables {
#     configure_aws                 = true
#     initial_aws_access_key_id     = "AKIAXQY5RIOOOOOO"
#     initial_aws_secret_access_key = "aoeu1234"
#   }
#   assert {
#     condition     = length(vault_aws_secret_backend.aws) == 1
#     error_message = "AWS Secret Backend not created when expected"
#   }
# }
