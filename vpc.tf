resource "aws_vpc_endpoint_service" "discriminat" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.discriminat.arn]

  tags = local.tags
}

resource "aws_vpc_endpoint" "discriminat" {
  count = length(var.private_subnets)

  service_name      = aws_vpc_endpoint_service.discriminat.service_name
  vpc_endpoint_type = aws_vpc_endpoint_service.discriminat.service_type
  subnet_ids        = [var.private_subnets[count.index]]
  vpc_id            = data.aws_vpc.context.id
  auto_accept       = true

  tags = local.tags
}
