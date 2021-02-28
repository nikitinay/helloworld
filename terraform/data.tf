data aws_ami node {

  depends_on = [module.cluster]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${module.cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}
