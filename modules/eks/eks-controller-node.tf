variable "aws_region" {}
variable "ssh_private_key" {}
variable "index-name" {}
variable "splunk-token" {}
variable "controller_vars" {}
variable "worker_node_instance_types" {}
variable "asg_worker_node_vars" {}
variable "eks_cluster_vars" {}


resource "aws_instance" "arloec2" {

  ami                         = var.controller_vars.ami
  instance_type               = var.controller_vars.instance_type
  iam_instance_profile        = var.controller_vars.role
  user_data                   = base64encode(local.userdata)
  key_name                    = var.controller_vars.ssh_key
  subnet_id                   = var.controller_vars.subnet_id
  vpc_security_group_ids      = ["${var.controller_vars.security_group}"]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = var.controller_vars.root_disk
  }

  tags = {
    Name        = "${var.controller_vars.controller_hostname}"
    Class       = "${var.class}"
    Product     = "${var.product}"
    ClusterName = "${var.eks_cluster_vars.cluster_name}"
  }

}

resource "null_resource" "cluster" {
  depends_on = [
    "aws_eks_cluster.eks",
  "aws_instance.arloec2"]
  triggers = {
    cluster_instance_ids = "${aws_instance.arloec2.id}"
  }

  connection {
    type        = "ssh"
    host        = aws_instance.arloec2.private_ip
    user        = "ec2-user"
    private_key = file(var.ssh_private_key)

  }


  provisioner "remote-exec" {
    inline = [
      "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.eks.id}",
      "kubectl config view",
      "kubectl get svc",
      "kubectl get pods --all-namespaces",
      "sudo yum install vim git unzip -y",
      "git --version",
      "kubectl apply -f https://github.com/chetanpatel8476/terraform-eks/blob/master/files/aws-k8s-cni-1-7-5.yaml",
      "kubectl patch daemonset -n kube-system aws-node -p '{\"spec\": {\"template\": {\"spec\": {\"containers\": [{\"name\": \"aws-node\",\"env\": [{\"name\":\"WARM_IP_TARGET\",\"value\":\"5\"}]}]}}}}'"
    ]
  }
}

resource "local_file" "kubeconfig" {
  content  = data.template_file.kubeconfig.rendered
  filename = "${path.module}/kubeconfig${aws_eks_cluster.eks.id}.yaml"
}

resource "local_file" "config_map_aws_auth" {
  content  = data.template_file.configmap.rendered
  filename = "${path.module}/config-map-aws-auth${aws_eks_cluster.eks.id}.yaml"
}

resource "null_resource" "controller-node-script" {
  depends_on = ["aws_autoscaling_group.eks"]
  triggers = {
    cluster_instance_ids = "${aws_instance.arloec2.id}",
    autoscaling_id       = "${aws_autoscaling_group.eks.id}",
  }

  connection {
    type        = "ssh"
    host        = aws_instance.arloec2.private_ip
    user        = "ec2-user"
    private_key = file(var.ssh_private_key)

  }

  provisioner "file" {
    source      = "${path.module}/eks-admin-service-account.yaml"
    destination = "/home/ec2-user/eks-admin-service-account.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config-map-aws-auth${aws_eks_cluster.eks.id}.yaml"
    destination = "/home/ec2-user/config-map-aws-auth.yaml"
  }




  provisioner "remote-exec" {
    inline = [
      "kubectl apply -f /home/ec2-user/config-map-aws-auth.yaml",
      "kubectl get nodes ",
      "kubectl get pods -n kube-system",
      "kubectl get pods --all-namespaces",
      "sleep 10",
      "kubectl get pods --all-namespaces",
      "kubectl apply -f /home/ec2-user/eks-admin-service-account.yaml",
      "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3",
      "chmod 700 get_helm.sh",
      "sudo ./get_helm.sh",
      "sudo cp -p /usr/local/bin/helm /usr/bin/",
      "sleep 30",
      "echo 'Installing local dns'",
      "kubectl apply -f https://github.com/chetanpatel8476/terraform-eks/blob/master/files/nodelocaldns-filled.yaml",
      "/usr/bin/wget https://github.com/chetanpatel8476/terraform-eks/blob/master/files/eks-automation-provisions.zip",
      "unzip eks-automation-provisions.zip",
      "kubectl apply -f eks-automation-provisions/metrics-server-deployment/1.8+/",
      "sed -i 's/cluster-name-placeholder/${aws_eks_cluster.eks.id}/g' eks-automation-provisions/cluster-autoscaler.yaml",
      "kubectl apply -f eks-automation-provisions/cluster-autoscaler.yaml",
    ]
  }
}
