locals {
  tags = merge(
    {
      "Name" : "DiscrimiNAT",
      "documentation" : "https://chasersystems.com/docs/"
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

locals {
  cc_byol = var.byol == null ? "" : "- encoding: base64\n  path: /etc/chaser/licence-key.der\n  permissions: 0404\n  content: ${var.byol}\n"
  cc_ashr = var.ashr == true ? "" : "- path: /etc/chaser/disable_automated-system-health-reporting\n  permissions: 0404\n"
}

locals {
  cc_write_files = "${local.cc_byol}${local.cc_ashr}"
}

locals {
  cloud_config = local.cc_write_files == "" ? "" : "#cloud-config\nwrite_files:\n${local.cc_write_files}"
}

locals {
  iam_get_merged_ssm_params = concat(["arn:aws:ssm:*:*:parameter/DiscrimiNAT*"], var.iam_get_additional_ssm_params)
  iam_get_json_ssm_params   = jsonencode(local.iam_get_merged_ssm_params)
  iam_get_json_secrets      = jsonencode(var.iam_get_additional_secrets)

  iam_policy_json = templatefile("${path.module}/iam_policy.json.tftpl", { iam_get_json_ssm_params = local.iam_get_json_ssm_params, iam_get_json_secrets = local.iam_get_json_secrets })
}
