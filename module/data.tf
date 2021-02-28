
data aws_availability_zones available {}

data template_file kube_config {

  depends_on = [aws_eks_cluster.cluster]

  template   = file("${path.module}/kube-config.template")

  vars = {
    cluster_name    = aws_eks_cluster.cluster.name
    user_name       = var.USERNAME
    endpoint        = aws_eks_cluster.cluster.endpoint
    cluster_ca      = aws_eks_cluster.cluster.certificate_authority[0].data
  }
}

data template_file ca_cert {

  depends_on = [aws_eks_cluster.cluster]
  
  template   = file("${path.module}/ca-cert.template")

  vars = {
    ca_cert = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
  }
}
