provider "aws" {
  region = local.region
}

locals {
  # TODO - Update to suite
  name   = "example"
  region = "us-west-2"
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
