
output name {
  value = aws_eks_cluster.cluster.name
}

output version {
  value = aws_eks_cluster.cluster.version
}

output endpoint {
  value = aws_eks_cluster.cluster.endpoint
}

output certificate_authority_data {
  value = aws_eks_cluster.cluster.certificate_authority[0].data
}

output vpc_id {
  value = aws_vpc.vpc.id
}

output security_group_id {
  value = aws_security_group.cluster.id
}

output node_security_group_id {
  value = aws_security_group.node.id
}

output node_role_arn {
  value = aws_iam_role.node.arn
}

output iam_instance_profile {
  value = aws_iam_instance_profile.profile.name
}

output instance_profile {
  value = aws_iam_instance_profile.profile.name
}

output private_subnet_ids {
  value = aws_subnet.private_subnet.*.id
}

output public_subnet_ids {
  value = aws_subnet.public_subnet.*.id
}

output private_subnet_by_zones {
  value = {
    for subnet in aws_subnet.private_subnet:
      subnet.availability_zone => subnet.id
  }
}

output public_subnet_by_zones {
  value = {
  for subnet in aws_subnet.public_subnet:
    subnet.availability_zone => subnet.id
  }
}

output node_sg {
  value = aws_security_group.node.id
}

output OWNER_TAG {
  value = var.OWNER_TAG
}

output PROJECT_TAG {
  value = var.PROJECT_TAG
}