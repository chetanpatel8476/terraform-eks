# EKS Terraform module
provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::454143665149:role/EC2toEKS"
  }
  region = lookup(var.aws_region, var.azzone)
}

module "eks" {
  source                     = "../modules/eks"
  class                      = var.class
  product                    = var.product
  ssh_private_key            = var.ssh_private_key
  k8s_version                = var.k8s_version
  aws_region                 = lookup(var.aws_region, var.azzone)
  env                        = var.env
  hostname_prefix            = var.asg_worker_node_vars.asg_hostname
  azzone                     = var.azzone
  application                = var.application
  mydevopsint_cidr           = var.mydevopsint_cidr
  controller_vars            = var.controller_vars
  worker_node_instance_types = var.worker_node_instance_types
  asg_worker_node_vars       = var.asg_worker_node_vars
  eks_cluster_vars           = var.eks_cluster_vars
}