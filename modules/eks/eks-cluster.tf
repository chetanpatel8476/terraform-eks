# EKS Cluster Resources
variable "k8s_version" {}
variable "mydevopsint_cidr" {}
resource "aws_iam_role" "cluster" {
  name = "${var.eks_cluster_vars.cluster_name}-eks-cluster-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.cluster.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       =  "${aws_iam_role.cluster.name}" 
}

resource "aws_security_group" "cluster" {
  name = "${var.eks_cluster_vars.cluster_name}-eks-cluster-sg"  
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.eks_cluster_vars.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name =  "${var.eks_cluster_vars.cluster_name}-eks-node-sg"
  }
}
resource "aws_security_group_rule" "cluster-ingress-apiendpoint-https" {
  description              = "Cluster API endpoint access from inside arlo"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cluster.id}"
  cidr_blocks              = ["${var.mydevopsint_cidr}"]
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cluster.id}"
  source_security_group_id = "${aws_security_group.node.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster-ingress-workstation-https" {
  cidr_blocks       = ["${local.workstation-external-cidr}"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.cluster.id}"
  to_port           = 443
  type              = "ingress"
}

resource "aws_eks_cluster" "eks" {
  name     = "${var.eks_cluster_vars.cluster_name}"
  role_arn = "${aws_iam_role.cluster.arn}"
  version = "${var.k8s_version}"
  vpc_config {
    security_group_ids = ["${aws_security_group.cluster.id}"]
    subnet_ids         = "${split(",", var.eks_cluster_vars.subnet_ids)}"
    endpoint_public_access = false
    endpoint_private_access = true
  }

  depends_on = [
   "aws_instance.arloec2",
   "aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy",
  ]
}




locals {
   ca_list = "${concat(flatten(aws_eks_cluster.eks.certificate_authority), list(map("data", "")))}"
   certificate_authority_data  = "${lookup(local.ca_list[0], "data")}"
   cluster_id = "${aws_eks_cluster.eks.id}"
   endpoint   = "${aws_eks_cluster.eks.endpoint}"
  }


output "ca_data" {

 value ="{local.certificate_authority_data}"
}

data "template_file" "kubeconfig" {
  template = "${file("${path.module}/kubeconfig.tpl")}"

  vars = {
    server                     = "${aws_eks_cluster.eks.endpoint}"
    certificate_authority_data = "${local.certificate_authority_data}"
    cluster_name               = "${aws_eks_cluster.eks.id}"
  }
}

data "template_file" "userdata" {
  template = "${file("${path.module}/userdata.tpl")}"

  vars = {
    endpoint                   = "${aws_eks_cluster.eks.endpoint}"   
    certificate_authority_data = "${local.certificate_authority_data}"
    cluster_id                 = "${aws_eks_cluster.eks.id}"
    azzone                     = "${var.azzone}"
    env                        = "${var.env}"
    aws_region                 = "${var.aws_region}"

  }
}

