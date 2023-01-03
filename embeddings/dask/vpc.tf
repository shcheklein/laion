provider "aws" {
  region = local.region
}

variable "vpc_id" {}

locals {
  name   = "dask"
  region = "us-east-2"

  tags = {
    Owner = "Ivan"
  }
}

data "aws_subnets" "eks_vpc" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_subnet" "eks_subnet" {
  for_each = toset(data.aws_subnets.eks_vpc.ids)
  id       = each.value
}


locals {
  private_subnet_ids = [for s in data.aws_subnet.eks_subnet : s.id if can(regex("private", lower(s.tags["Name"])))]
}

data "aws_route_table" "private" {
  for_each  = toset(local.private_subnet_ids)
  subnet_id = each.key
}

locals {
  private_route_tables_ids = [for t in data.aws_route_table.private : t.id]
}

data "aws_vpc" "eks" {
  id = var.vpc_id
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  vpc_id = data.aws_vpc.eks.id

  endpoints = {
    s3 = {
      service_type    = "Gateway"
      service         = "s3"
      route_table_ids = local.private_route_tables_ids
      tags            = { Name = "s3-vpc-endpoint" }
    },
  }

  tags = merge(local.tags, {
    Project  = "Secret"
    Endpoint = "true"
  })
}
