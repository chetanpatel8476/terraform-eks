#Variables Configuration

variable "class" {
  default = "Dev"
}

variable "product" {
  default = "MyDevOps"
}

variable "k8s_version" {
  default = "1.21"
}

variable "ssh_private_key" {
  default = "/opt/.secrets/cpatel.pem"
}

variable "zone" {
  default = "z1"
}

variable "aws_region" {
  default = {
    z1 = "eu-west-1"
    z2 = "us-west-2"
    z3 = "ap-southeast-1"
    z4 = "ap-southeast-2"
  }
}

variable "azzone" {
  default = "z1"
}

variable "env" {
  default = "Dev"
}

variable "application" {
  default = "be-common-mydevops-dev"
}

variable "mydevopsint_cidr" {
  default = "10.0.0.0/16"
}

#eks_cluster_vars[start]
variable "eks_cluster_vars" {
type = map
default = {
cluster_name= "be-common-z1-mydevops-dev"
subnet_ids="subnet-09fdfb012ad4d7ef8,subnet-092d87c26f9352d6f"
vpc_cidr = "10.0.0.0/16"
image_id = "ami-045bd3b159d56293e"
vpc_id = "vpc-0c3d562eeeca168ec"
}
}

variable "asg_worker_node_vars" {
type = map
default = {
asg_min = 2
asg_max = 5
asg_desired = 2
asg_root_disk = 50
asg_hostname = "be-common-z1-mydevops-dev"
lt_instance_type = "t2.micro"
  }
}

variable "worker_node_instance_types" {
  type = list(map(any))
  default = [
    {instance_type = "t2.micro" ,weighted_capacity = "1"},
    {instance_type = "t2.medium" ,weighted_capacity = "2"},
    {instance_type = "t2.small" ,weighted_capacity = "1"},
    {instance_type = "t2.large" ,weighted_capacity = "2"}
     ]
}
#cpu_var[end]

#controller_vars[start]
variable "controller_vars" {
type = map
default = {
root_disk = 50
controller_hostname = "controller-be-common-z1-mydevops-dev"
instance_type = "t3.medium"
ami = "ami-06020ced87ce0fb93"
subnet_id = "subnet-09fdfb012ad4d7ef8"
ssh_key = "cpatel"
role = "EC2toEKS"
security_group = "sg-03da2a603f310c8f4"
  }
}
#controller_vars[end]