variable REGION {
  default = "eu-west-2"
}

variable NAME {
  default = "helloworld-k8s"
}

variable USERNAME {
  default = "aws"
}

variable VPC_CIDR {
  default = "10.0.0.0/22"
}

variable PUBLIC_SUBNET_CIDRS {
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable PRIVATE_SUBNET_CIDRS {
  default = ["10.0.2.0/24", "10.0.3.0/24"] 
}

variable STATE_DIR {
  default = "."
}

variable EKS_OWNER_TAG {
  default = "helloworld"
}

variable EKS_PROJECT_TAG {
  default = "helloworld"
}

variable REGISTRY_ROOT_CA {
  default =""
}

variable K8S_EKS_VERSION {
  default = "1.18"
}

