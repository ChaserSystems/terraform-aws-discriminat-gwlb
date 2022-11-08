locals {
  tags = merge(
    {
      "Name" : "DiscrimiNAT",
      "documentation" : "https://chasersystems.com/docs"
    },
    var.tags
  )
}

locals {
  delay_2_shutdown_drained = 15
  delay_3_eip_dissociation = 45
  delay_4_cache_priming    = 120
}

locals {
  max_possible_instances = (var.high_availability_mode == "cross-zone" ? var.per_region_max_instances : length(var.public_subnets) * var.per_az_max_instances)
}
