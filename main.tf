terraform {

  backend "s3" {
    bucket         = "<UPDATE>"
    key            = "<UPDATE>/terraform.tfstate"
    region         = "<UPDATE>"
    encrypt        = true
  }
}

provider "aws" {
  region = local.region

  assume_role {
    role_arn     = "<UPDATE>"
    session_name = local.name
  }
}

locals {
  # TODO - Update to suite
  name   = "example"
  region = "eu-central-1"
}

################################################################################
# Tags
# TODO - Replace with your own tags implementation
################################################################################

module "tags" {
  source  = "clowdhaus/tags/aws"
  version = "~> 1.1"

  application = "eks-ml-cbr"
  environment = "nonprod"
  repository  = "https://github.com/clowdhaus/eks-ml-cbr"
}

################################################################################
# Output
################################################################################

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}
