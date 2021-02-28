provider aws {
  region     = var.REGION
  version    = "~> 2.0"
}

module cluster {
  source                 = "../module"
  NAME                   = var.NAME
  REGION                 = var.REGION
  USERNAME               = var.USERNAME
  VPC_CIDR               = var.VPC_CIDR
  PUBLIC_SUBNET_CIDRS    = var.PUBLIC_SUBNET_CIDRS
  PRIVATE_SUBNET_CIDRS   = var.PRIVATE_SUBNET_CIDRS
  ENDPOINT_PUBLIC_ACCESS = true
  CONFIG_DIR             = var.STATE_DIR
  OWNER_TAG              = var.EKS_OWNER_TAG
  PROJECT_TAG            = var.EKS_PROJECT_TAG
  K8S_EKS_VERSION        = var.K8S_EKS_VERSION
  AZ_COVERAGE            = 2 #Cover 2 different AZ
}

resource "aws_key_pair" "this" {
  key_name   = "helloworldkey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCb3cFWcFhaLBgu+VjtQMUjtGTtu67tafF9S+na2SLrFRYJJ1za99Hu6Brj/ckNXmBKBbwnc+OzYqw+OXnf7alWJ75AXFK5LI3R19En3MbI7sRr4Pcs5rqpQEgm4LJvrCuILTkH5Wrj8K0xBWXjP2EUQOXtMDffQJ4Dk5GFsaP8qlfGxbPivVobUnfpXFFI/oudB4q27q/+b2gF6XeuMpojvqQBxYIvXWOTlpEFwrmqULEW6RHtxY4nmid0maiJEeNB2AbXGNb6VDm5TB6SfuP5F9aQIvq02EGYbh0l95xVRyiwx4r41Le1F/yzxl/GpYIi5J8Qv/EdnC3nULEs/7Iz"
}

locals {

  depends_on = [module.cluster]

  userdataHelloworld = <<EOF
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${module.cluster.endpoint}' --b64-cluster-ca '${module.cluster.certificate_authority_data}' '${module.cluster.name}' \
--kubelet-extra-args --node-labels=platform.isolation/nodegroup=helloworld,platform.isolation/owner=helloworld

EOF
}

resource aws_launch_configuration confHelloworld {

  depends_on                  = [module.cluster]

  associate_public_ip_address = true
  image_id                    = data.aws_ami.node.id
  instance_type               = "t3.medium"
  iam_instance_profile        = module.cluster.instance_profile
  name_prefix                 = module.cluster.name
  security_groups             = [module.cluster.node_security_group_id]
  user_data_base64            = "${base64encode(local.userdataHelloworld)}"
  enable_monitoring           = false
  key_name                    = "helloworldkey"

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_autoscaling_group groupHelloworld{

  depends_on           = [module.cluster, aws_launch_configuration.confHelloworld]

  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.confHelloworld.id
  max_size             = 2
  min_size             = 2
  name                 = "${module.cluster.name}_Helloworld"
  vpc_zone_identifier  = module.cluster.private_subnet_ids #distribute nodes between AZ

  tag {
    key                 = "Name"
    value               = "${module.cluster.name}_Helloworld"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${module.cluster.name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "owner"
    value               = module.cluster.OWNER_TAG
    propagate_at_launch = true
  }

  tag {
    key                 = "project"
    value               = module.cluster.PROJECT_TAG
    propagate_at_launch = true
  }
}

