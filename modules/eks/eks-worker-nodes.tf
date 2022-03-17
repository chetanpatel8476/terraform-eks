# EKS Worker Nodes Resources
variable "env" {}
variable "hostname_prefix" {}
variable "class"{}
variable "product"{}
variable "application"{}

resource "aws_iam_role" "node" {
  name=   "${var.eks_cluster_vars.cluster_name}-eks-node-role"
  assume_role_policy = <<POLICY
{
 "Version": "2012-10-17",
  "Statement": [
    {
     "Effect": "Allow",
     "Principal": {
      "Service": "ec2.amazonaws.com"
     },
     "Action": "sts:AssumeRole"
   }
 ]
}
 POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
 role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
	role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
 role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonS3ReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.eks_cluster_vars.cluster_name}eks-node-instance-profile"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_security_group" "node" {
  name        = "${var.eks_cluster_vars.cluster_name}-eks-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${var.eks_cluster_vars.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.eks_cluster_vars.cluster_name}-eks-node-sg",
     "kubernetes.io/cluster/${var.eks_cluster_vars.cluster_name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        =  "${aws_security_group.node.id}"
  source_security_group_id =  "${aws_security_group.node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 0
  protocol                 = "tcp"
  security_group_id        =  "${aws_security_group.node.id}"
  source_security_group_id =  "${aws_security_group.cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}


resource "aws_security_group_rule" "node-ingress-alltraffic" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 0
  protocol                 = "all"
  security_group_id        =  "${aws_security_group.node.id}"
  cidr_blocks		   = ["${var.eks_cluster_vars.vpc_cidr}"]
  to_port                  = 0
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-udp" {
  description              = "udp change"
  from_port                = 53
  protocol                 = "udp"
  security_group_id        =  "${aws_security_group.node.id}"
  cidr_blocks              = ["${var.eks_cluster_vars.vpc_cidr}"]
  to_port                  = 53
  type                     = "ingress"
}


#resource "aws_launch_configuration" "eks" {
#depends_on = ["null_resource.cluster"]
#  associate_public_ip_address = false
#  iam_instance_profile        = "${aws_iam_instance_profile.node.*.name}"
#  image_id                    = "${var.image_id}"
#  instance_type               = "${var.node_instance_type}"
#  name_prefix                 = "${var.cluster_name[var.azzone]}-eks-"
#  key_name		      = "${var.ssh_key}"
#  security_groups             = ["${aws_security_group.node.*.id}"]
#  user_data_base64            =  "${base64encode(data.template_file.userdata.*.rendered)}"
  
#  root_block_device   {
#    volume_size = "${var.root_disk_size}"
#  }

# lifecycle {
#    create_before_destroy = true
#  }
#}

resource "aws_launch_template" "eks" {
  depends_on = ["null_resource.cluster"]
  #count= "${length(var.cluster_name[var.azzone])}"
  name_prefix                 = "${var.eks_cluster_vars.cluster_name}-lt"
  image_id                    = "${var.eks_cluster_vars.image_id}"
  instance_type               = "${var.asg_worker_node_vars.lt_instance_type}"
  key_name                    = "${var.controller_vars.ssh_key}"
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = ["${aws_security_group.node.id}"]
    delete_on_termination       = true
  }
  iam_instance_profile {
        name =  "${aws_iam_instance_profile.node.name}"
   }
   block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = "${var.asg_worker_node_vars.asg_root_disk}"
      encrypted = true
    }
  }
  user_data = "${base64encode(data.template_file.userdata.rendered)}"
  lifecycle {
   create_before_destroy = true
 }
}
resource "aws_autoscaling_group" "eks" {
depends_on =  ["aws_launch_template.eks"]
  desired_capacity     = "${var.asg_worker_node_vars.asg_desired}"
#  launch_configuration = "${aws_launch_configuration.eks.*.id}"
  max_size             = "${var.asg_worker_node_vars.asg_max}"
  min_size             = "${var.asg_worker_node_vars.asg_min}"
  name                 = "${var.eks_cluster_vars.cluster_name}-eks-asg"
  vpc_zone_identifier  = ["${var.eks_cluster_vars.subnet_ids}"]
  suspended_processes  = ["AZRebalance"]
  enabled_metrics = ["GroupDesiredCapacity", "GroupInServiceCapacity", "GroupPendingCapacity", "GroupMinSize", "GroupMaxSize", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupStandbyCapacity", "GroupTerminatingCapacity", "GroupTerminatingInstances", "GroupTotalCapacity", "GroupTotalInstances"]
mixed_instances_policy {
    launch_template {
        launch_template_specification {
        launch_template_id = "${aws_launch_template.eks.id}"
        version            = "$Latest"
      }
      dynamic "override" {
        for_each = var.worker_node_instance_types
        content {
          instance_type     = lookup(override.value, "instance_type", null)
          weighted_capacity  = lookup(override.value, "weighted_capacity", null)
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.eks_cluster_vars.cluster_name}-eks-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.eks_cluster_vars.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.eks_cluster_vars.cluster_name}"
    value               = "true"
    propagate_at_launch = true
  }

tag {
    key                 = "Class"
    value               = "${var.class}"
    propagate_at_launch = true
  }


tag {
    key                 = "Product"
    value               = "${var.product}"
    propagate_at_launch = true
  }
tag {
    key                 = "Application"
    value               = "${var.application}"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }

}

data "template_file" "configmap" {
  template = "${file("${path.module}/configmap.tpl")}"

  vars = {
      rolearn = "${aws_iam_role.node.arn}"
  }
}

