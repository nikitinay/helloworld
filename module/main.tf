provider local {

  version = "~> 1.3"
}

provider template {

  version  = "~> 2.1"
}


provider aws {
  region     = var.REGION
  version    = "~> 2.7"
}


locals {
  azCount = var.AZ_COVERAGE == 0 ? length(data.aws_availability_zones.available.names) : var.AZ_COVERAGE
}

resource aws_vpc vpc {

  cidr_block = var.VPC_CIDR
  enable_dns_hostnames = true

  tags = map(
     "Name", format("%s-node", var.NAME),
     "kubernetes.io/cluster/${var.NAME}", "shared",
     "owner", var.OWNER_TAG,
     "project", var.PROJECT_TAG,
  )

}
# Internet gateway for public subnets
resource aws_internet_gateway gateway {

  depends_on = [aws_vpc.vpc]

  vpc_id = aws_vpc.vpc.id

  tags = {
    "Name" = format("%s", var.NAME),
    "owner" = var.OWNER_TAG,
    "project" = var.PROJECT_TAG,
  }
}
# Public subnet and routing
resource aws_subnet public_subnet {

  depends_on = [aws_vpc.vpc]
  count = local.azCount

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.PUBLIC_SUBNET_CIDRS[count.index]
  vpc_id            = aws_vpc.vpc.id

  tags = {
    "Name" = format("public_%s_az_%s", var.NAME, data.aws_availability_zones.available.names[count.index])
    "kubernetes.io/cluster/${var.NAME}" = "shared"
    "owner" = var.OWNER_TAG
    "project" = var.PROJECT_TAG
    "type" = format("public_%s", var.NAME)
  }
}

resource aws_route_table public_subnet_rtable {

  depends_on = [aws_vpc.vpc, aws_internet_gateway.gateway]

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    "Name" = format("%s-public_subnet_rtable", var.NAME)
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_route_table_association public_rt_association {

  depends_on = [aws_subnet.public_subnet, aws_route_table.public_subnet_rtable]

  count = local.azCount

  subnet_id      = aws_subnet.public_subnet.*.id[count.index]
  route_table_id = aws_route_table.public_subnet_rtable.id
}
#Elastic IP for nat gw:
resource "aws_eip" nat_gw_eip {
  vpc = true
  count = local.azCount
  tags = {
    "Name" = format("%s-nat_gw_eip", var.NAME)
    "kubernetes.io/cluster/${var.NAME}" = "shared"
    "owner" =  var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}
#Nat gateway for public subnet:
resource "aws_nat_gateway" nat_gw {
  depends_on = [aws_vpc.vpc,aws_subnet.public_subnet,aws_eip.nat_gw_eip]

  count = local.azCount
  subnet_id = aws_subnet.public_subnet.*.id[count.index]
  allocation_id =  aws_eip.nat_gw_eip.*.id[count.index]

  tags = {
    "Name" = format("%s-nat_gw_az_%s", var.NAME,data.aws_availability_zones.available.names[count.index])
    "kubernetes.io/cluster/${var.NAME}" = "shared"
    "owner" =  var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

# Private subnet and routing
resource aws_subnet private_subnet {

  depends_on = [aws_vpc.vpc]

  count = local.azCount

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.PRIVATE_SUBNET_CIDRS[count.index]
  vpc_id            = aws_vpc.vpc.id

  tags = {
    "Name" = format("private_%s_az_%s", var.NAME,data.aws_availability_zones.available.names[count.index])
    "kubernetes.io/cluster/${var.NAME}"= "shared"
    "owner" = var.OWNER_TAG
    "project" = var.PROJECT_TAG
    "type" = format("private_%s", var.NAME)
  }
}

resource aws_route_table private_subnet_rtable {

  depends_on = [aws_vpc.vpc, aws_nat_gateway.nat_gw]
  vpc_id = aws_vpc.vpc.id

  count = local.azCount

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id =aws_nat_gateway.nat_gw.*.id[count.index]
  }

  tags = {
    "Name" = format("%s-private_subnet_rtable_az_%s", var.NAME,data.aws_availability_zones.available.names[count.index])
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_route_table_association private_rt_association {

  depends_on = [aws_subnet.private_subnet, aws_route_table.private_subnet_rtable]
  count = local.azCount

  subnet_id      = aws_subnet.private_subnet.*.id[count.index]
  route_table_id = aws_route_table.private_subnet_rtable.*.id[count.index]
}


resource aws_iam_role cluster {

  name = format("%s-cluster", var.NAME)

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
  tags = {
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_iam_role_policy_attachment AmazonEKSClusterPolicy {

  depends_on = [aws_iam_role.cluster]

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource aws_iam_role_policy_attachment AmazonEKSServicePolicy {

  depends_on = [aws_iam_role.cluster]

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

resource aws_security_group cluster {

  depends_on = [aws_vpc.vpc]

  name        = format("%s-cluster", var.NAME)
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.NAME
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_security_group_rule api {

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_security_group.cluster
  ]

  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  to_port           = 443
  type              = "ingress"
}

resource aws_eks_cluster cluster {

  depends_on = [aws_iam_role.cluster, aws_security_group.cluster]

  name     = var.NAME
  role_arn = aws_iam_role.cluster.arn
  version  = var.K8S_EKS_VERSION

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = var.ENDPOINT_PUBLIC_ACCESS
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = aws_subnet.private_subnet.*.id

  }

  tags = {
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}


resource aws_iam_role node {

  depends_on = [aws_iam_role.cluster]

  name = format("%s-node", var.NAME)

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
  tags = {
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_iam_instance_profile profile {

  depends_on = [aws_eks_cluster.cluster, aws_iam_role.node]

  name = aws_eks_cluster.cluster.name
  role = aws_iam_role.node.name
}

resource aws_iam_role_policy_attachment AmazonEKSWorkerNodePolicy {

  depends_on = [aws_iam_role.node]

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource aws_iam_role_policy_attachment AmazonEKS_CNI_Policy {

  depends_on = [aws_iam_role.node]

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource aws_iam_role_policy_attachment AmazonEC2ContainerRegistryReadOnly {

  depends_on = [aws_iam_role.node]

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource aws_security_group node {

  depends_on = [aws_vpc.vpc]

  name        = format("%s-node", var.NAME)
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", format("%s-node", var.NAME),
     "kubernetes.io/cluster/${var.NAME}", "owned",
     "owner", var.OWNER_TAG,
     "project", var.PROJECT_TAG,
    )
  }"
}

resource aws_security_group_rule node {

  depends_on = [aws_security_group.node]

  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource aws_security_group_rule cluster {

  depends_on = [aws_security_group.node, aws_security_group.cluster]

  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource aws_security_group_rule pod {

  depends_on = [aws_security_group.node, aws_security_group.cluster]

  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 443
  type                     = "ingress"
}

resource local_file kube_config {

  depends_on = [aws_eks_cluster.cluster]

  content  = data.template_file.kube_config.rendered
  filename = format("%s/%s", var.CONFIG_DIR, var.KUBE_CONFIG)
}

resource local_file ca_cert {

  depends_on = [aws_eks_cluster.cluster]

  content  = data.template_file.ca_cert.rendered
  filename = format("%s/%s", var.CONFIG_DIR, var.CA_CERT)
}







