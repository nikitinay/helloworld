
variable REGION {
  default = "eu-west-2"
}

variable NAME {
  default = "cluster"
}

variable VPC_CIDR {
  default = ""
}

variable PUBLIC_SUBNET_CIDRS {
  default = [""]
}
variable PRIVATE_SUBNET_CIDRS {
  default = [""]
}

variable USERNAME {
  default = "aws"
}

variable ENDPOINT_PUBLIC_ACCESS {
  default = true
}

variable KUBE_CONFIG {
  default = "cluster.kube-config"
}

variable CA_CERT {
  default = "cluster.ca-cert"
}

variable CONFIG_DIR {
  default = "."
}

variable OWNER_TAG {
  default = ""
}

variable PROJECT_TAG {
  default = ""
}

variable K8S_EKS_VERSION {
  default = ""
}

variable AZ_COVERAGE {
  default = 0 # means all zones
              # 1 - 1 zone, 2 - 2 zones, etc.
}
