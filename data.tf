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
  owners      = [var.ami_owner]
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = var.ami_owner == "aws-marketplace" ? "product-code" : "owner-id"
    values = [(var.ami_owner == "aws-marketplace" && var.byol == null) ? "bz1yq0sc5ta99w5j7jjwzym8g" : (var.ami_owner == "aws-marketplace" && var.byol != null) ? "a7z5gi2mkpzvo93r2e8csl2ld" : var.ami_owner]
  }

  filter {
    name   = "name"
    values = var.ami_auto_update ? ["DiscrimiNAT-*"] : ["DiscrimiNAT-${var.ami_version}"]
  }
}

data "aws_eips" "discriminat" {
  tags = {
    discriminat = "*"
  }
}
