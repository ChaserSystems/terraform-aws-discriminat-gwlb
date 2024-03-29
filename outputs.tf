output "cloudwatch_log_group_name" {
  value       = "DiscrimiNAT"
  description = "Name of the CloudWatch Log Group where DiscrimiNAT instances will log traffic flow and configuration changes. Useful for automating any logging routing configuration."
}

output "target_gwlb_endpoints" {
  value       = [for k, v in aws_vpc_endpoint.discriminat : { id : v.id, route_table_id : data.aws_route_table.private_subnet[k].route_table_id }]
  description = "Map of Route Table IDs to VPC Endpoint IDs (Gateway Load Balancer) for setting as targets to 0.0.0.0/0 in routing tables of the Private Subnets. A Terraform example of using these in an `aws_route` resource can be found at https://github.com/ChaserSystems/terraform-aws-discriminat-gwlb#deployment-examples, under 'Entirely new VPC with DiscrimiNAT filtering for Private Subnets'"
}
