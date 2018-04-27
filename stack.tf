terraform {
  required_version = "0.11.7"

  backend "s3" {
    bucket  = "buildkite-docker-bootstrap-terraform-state"
    key     = "buildkite-docker-bootstrap.tfstate"
    encrypt = true

    dynamodb_table = "buildkite-docker-bootstrap-terraform-lock"

    profile = "buildkite-docker-bootstrap"
    region  = "eu-west-1"
  }
}

provider "aws" {
  version = "1.16.0"

  profile = "buildkite-docker-bootstrap"
  region  = "eu-west-1"
}

provider "template" {
  version = "1.0.0"
}

data "aws_ssm_parameter" "agent_token" {
  name = "/buildkite/agent-token"
}

resource "aws_cloudformation_stack" "buildkite" {
  name         = "buildkite-docker-bootstrap"
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v3.0.0/aws-stack.json"
  capabilities = ["CAPABILITY_NAMED_IAM"]

  parameters {
    BuildkiteAgentToken = "${data.aws_ssm_parameter.agent_token.value}"
    InstanceType        = "t2.micro"
    AgentsPerInstance   = 1
    RootVolumeSize      = 100
    KeyName             = "buildkite-docker-bootstrap"
    ECRAccessPolicy     = "poweruser"
    SecretsBucket       = "${aws_s3_bucket.secrets.id}"
    BootstrapScriptUrl  = "s3://${aws_s3_bucket.secrets.id}/${aws_s3_bucket_object.elastic_bootstrap.id}"
    AvailabilityZones   = "eu-west-1a,eu-west-1b,eu-west-1c"
    MinSize             = 0
    MaxSize             = 1
    ScaleUpAdjustment   = 1
    ScaleDownAdjustment = -1
    ScaleDownPeriod     = 600
  }
}

resource "aws_ecr_repository" "agent" {
  name = "agent"
}

resource "aws_ecr_lifecycle_policy" "agent" {
  repository = "${aws_ecr_repository.agent.name}"

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep untagged images for 1 week",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countNumber": 7,
        "countUnit": "days"
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF
}

resource "aws_s3_bucket" "secrets" {
  bucket = "buildkite-docker-bootstrap-secrets"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_object" "docker_bootstrap" {
  bucket  = "${aws_s3_bucket.secrets.id}"
  key     = "buildkite-docker-bootstrap"
  content = "${file("buildkite-docker-bootstrap")}"
}

data "template_file" "elastic_bootstrap" {
  template = "${file("buildkite-elastic-bootstrap")}"

  vars {
    source = "s3://${aws_s3_bucket.secrets.id}/${aws_s3_bucket_object.docker_bootstrap.id}"
    target = "/usr/local/bin/${aws_s3_bucket_object.docker_bootstrap.id}"
  }
}

resource "aws_s3_bucket_object" "elastic_bootstrap" {
  bucket  = "${aws_s3_bucket.secrets.id}"
  key     = "buildkite-elastic-bootstrap"
  content = "${data.template_file.elastic_bootstrap.rendered}"
}
