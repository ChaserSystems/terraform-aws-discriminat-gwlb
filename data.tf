data "aws_subnet" "public_subnet" {
  count = length(var.public_subnets)

  id = var.public_subnets[count.index]
}

data "aws_route_table" "private_subnet" {
  count = length(var.private_subnets)

  subnet_id = var.private_subnets[count.index]
}

data "aws_vpc" "context" {
  id = data.aws_subnet.public_subnet[0].vpc_id
}

data "aws_ami" "discriminat" {
  owners      = [var.ami_owner == null ? "aws-marketplace" : var.ami_owner]
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = var.ami_owner == null ? "product-code" : "name"
    values = [var.ami_owner == null ? "a83las5cq95zkg3x8i17x6wyy" : var.ami_name]
  }

  filter {
    name   = "name"
    values = var.ami_name == null ? ["DiscrimiNAT-2.5.*"] : [var.ami_name]
  }
}

data "aws_eips" "discriminat" {
  tags = {
    discriminat = "*"
  }
}
