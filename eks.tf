################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.33"

  cluster_name    = "example"
  cluster_version = "1.31"

  # To facilitate easier interaction for demonstration purposes
  cluster_endpoint_public_access = true

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources into the cluster
  enable_cluster_creator_admin_permissions = true

  # These will become the default in the next major version of the module
  bootstrap_self_managed_addons   = false
  enable_irsa                     = false
  enable_security_groups_for_pods = false

  cluster_addons = {
    aws-efs-csi-driver = {
      pod_identity_role_arn = [{
        role_arn        = module.aws_efs_csi_driver_pod_identity.iam_role_arn
        service_account = "efs-csi-controller-sa"
      }]
    }
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    ingress_efs = {
      description      = "EFS 2049/tcp ingress"
      protocol         = "tcp"
      from_port        = 2049
      to_port          = 2049
      type             = "ingress"
      cidr_blocks      = module.vpc.private_subnets_cidr_blocks
    }
  }

  eks_managed_node_groups = {
    # This node group is for core addons such as CoreDNS
    default = {
      ami_type = "AL2023_x86_64_STANDARD"
      instance_types = [
        "m7a.xlarge",
        "m7i.xlarge",
      ]

      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
    g6 = {
      ami_type = "AL2023_x86_64_NVIDIA"
      instance_types = [
        "g6e.12xlarge",
      ]

      # FYI - https://github.com/bryantbiggs/eks-desired-size-hack
      min_size     = 2
      max_size     = 5
      desired_size = 2

      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              instance:
                localStorage:
                  strategy: RAID0
          EOT
        }
      ]

      labels = {
        "nvidia.com/gpu.present" = "true"
      }

      taints = {
        # Ensure only GPU workloads are scheduled on this node group
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
    p5-cbr = {
      # Flip to `true` to create
      create   = false
      ami_type = "AL2023_x86_64_NVIDIA"
      instance_types = [
        "p5.48xlarge",
      ]

      min_size     = 2
      max_size     = 5
      desired_size = 2

      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              instance:
                localStorage:
                  strategy: RAID0
          EOT
        }
      ]

      labels = {
        "nvidia.com/gpu.present" = "true"
      }

      taints = {
        # Ensure only GPU workloads are scheduled on this node group
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # Capacity reservations are restricted to a single availability zone
      # TODO - update for the zone where the reseravtion is allocated
      subnet_ids = element(module.vpc.private_subnets, 0)

      # ML capacity block reservation
      capacity_type = "CAPACITY_BLOCK"
      instance_market_options = {
        market_type = "capacity-block"
      }
      capacity_reservation_specification = {
        capacity_reservation_target = {
          capacity_reservation_id = var.capacity_reservation_id
        }
      }
    }
  }

  tags = module.tags.tags
}

################################################################################
# EFS CSI Driver Pod Identity IAM Role
################################################################################

module "aws_efs_csi_driver_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.9"

  name = "aws-efs-csi"

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "efs-csi-controller-sa"
    }
  }

  attach_aws_efs_csi_policy = true

  tags = module.tags.tags
}

################################################################################
# AWS Load Balancer Controller
################################################################################

module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.9"

  name = "aws-lbc"

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller-sa"
    }
  }

  attach_aws_lb_controller_policy = true

  tags = module.tags.tags
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.11.1"
  namespace  = "kube-system"
  wait       = false

  values = [
    <<-EOT
      clusterName: ${module.eks.cluster_name}
    EOT
  ]
}

################################################################################
# NVIDIA Device Plugin
################################################################################

resource "helm_release" "nvidia_device_plugin" {
  name             = "nvidia-device-plugin"
  repository       = "https://nvidia.github.io/k8s-device-plugin"
  chart            = "nvidia-device-plugin"
  version          = "0.17.0"
  namespace        = "nvidia-device-plugin"
  create_namespace = true
  wait             = false
}
