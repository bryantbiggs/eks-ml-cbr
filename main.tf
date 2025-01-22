# terraform {

#   backend "s3" {
#     bucket         = "<UPDATE>"
#     key            = "<UPDATE>/terraform.tfstate"
#     region         = "<UPDATE>"
#     encrypt        = true
#   }
# }

provider "aws" {
  region = local.region

  # assume_role {
  #   role_arn     = "<UPDATE>"
  #   session_name = local.name
  # }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

locals {
  name   = "eks-ml-cbr"
  region = "us-east-1"
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
