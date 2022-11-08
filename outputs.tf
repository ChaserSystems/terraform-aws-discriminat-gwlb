output "target_gwlb_endpoints" {
  value       = [for k, v in aws_vpc_endpoint.discriminat : { id : v.id, route_table_id : data.aws_route_table.private_subnet[k].route_table_id }]
  description = "Map of Route Table IDs to VPC Endpoint IDs (Gateway Load Balancer) for setting as targets to 0.0.0.0/0 in routing tables of the Private Subnets. A Terraform example of using these in an `aws_route` resource can be found at https://github.com/ChaserSystems/terraform-aws-discriminat-eni/blob/main/examples/aws_vpc/example.tf"
}
