/*
## NVIDIA K8s Device Plugin

The NVIDIA K8s device plugin, https://github.com/NVIDIA/k8s-device-plugin, will need to
be installed in the cluster in order to mount and utilize the GPUs in your pods. Add the
following affinity rule to your device plugin Helm chart values to ensure the device
plugin runs on nodes that have GPUs present (as identified via the MNG
labels provided below):

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
          - key: 'nvidia.com/gpu.present'
            operator: In
            values:
              - 'true'
```

By default, the NVIDIA K8s device values already contain a toleration that matches the taint applied
to the node group below.
*/
################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

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
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      pod_identity_role_arn = [{
        role_arn        = module.vpc_cni_pod_identity.iam_role_arn
        service_account = "aws-node"
      }]
    }
    eks-pod-identity-agent = {}
  }

  vpc_id                   = data.aws_vpc.this.id
  control_plane_subnet_ids = data.aws_subnets.control_plane.ids
  subnet_ids               = data.aws_subnets.data_plane.ids

  cluster_zonal_shift_config = {
    enabled = true
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
    gpu = {
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
      subnet_ids = data.aws_subnets.data_plane_reservation.ids

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
# EKS Pod Identity IAM Roles
################################################################################

module "vpc_cni_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.7"

  name = "vpc-cni"

  attach_aws_vpc_cni_policy = true
  aws_vpc_cni_enable_ipv4   = true

  tags = module.tags.tags
}
