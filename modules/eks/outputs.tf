output "eks_cluster_id" {
  description = "The name of the cluster"
  value       = join(",", aws_eks_cluster.eks.*.id)
}


output "instance_ip" {
  value = join("", aws_instance.arloec2.*.public_ip)
}



output "config_map_aws_auth" {
  description = "Kubernetes ConfigMap configuration for worker nodes to join the EKS cluster. https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html#required-kubernetes-configuration-to-join-worker-nodes"
  value       = join("", data.template_file.configmap.*.rendered)
}
