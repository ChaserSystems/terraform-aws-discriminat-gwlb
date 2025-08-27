# DiscrimiNAT Firewall, GWLB architecture

HTTPS, TLS, SSH, SFTP **micro-segmentation** firewall to filter VPC egress by hostnames. Simply specify allowed FQDNs within the respective apps' Security Groups' description fields. Apps will **not** require any proxy configuration.

---

![](https://chasersystems.com/img/aws-protocol-tls.gif)

---

[2-minute Demo Video](https://chasersystems.com/discriminat/aws/demo) | [Product Reviews at G2](https://www.g2.com/products/discriminat-firewall/reviews) | [AWS Marketplace Subscription (required)](https://aws.amazon.com/marketplace/pp/prodview-7ulmdnoq5jnwu)

---

Architecture with [Gateway Load Balancer (GWLB)](https://aws.amazon.com/elasticloadbalancing/gateway-load-balancer/) VPC Endpoints for Private Subnets' route table entries to the Internet, featuring:

🖧 High Availability

⚖ Load Balancing

🚀 Auto Scaling

---

### **Table of Contents**

[Quick Allowlist Building](#quick-allowlist-building)<br>
[Standards & Compliance ](#standards--compliance)<br>
[Reference Architectures](#reference-architectures)<br>
[Elastic IPs](#elastic-ips)<br>
[Other VPC Requirements](#other-vpc-requirements)<br>
[Deployment Examples](#deployment-examples)<br>
[Security Group Examples](#security-group-examples)<br>
[Allowlist Building Examples](#allowlist-building-examples)<br>
[More Help](#more-help)<br>
[Automated System Health Reporting](#automated-system-health-reporting)<br>
[Terraform Requirements](#requirements)<br>
[Terraform Inputs](#inputs)<br>
[Terraform Outputs](#outputs)<br>
[Terraform Resources](#resources)<br>

---

## Quick Allowlist Building

Use the `see-thru` mode to discover what needs to be in the allowlist for an app, by monitoring its outbound network activity first. Follow our [building an allowlist from scratch](https://chasersystems.com/docs/discriminat/aws/logs-ref#building-an-allowlist-from-scratch) recipe for use with CloudWatch.

> **Note**\
> Terraform example of a `see-thru` Security Group is [here](#allowlist-building-examples).

![](https://chasersystems.com/img/aws-see-thru.gif)

---

## Standards & Compliance

The DiscrimiNAT Firewall helps your organisation achieve

💳 PCI DSS v4.0, [Requirement 1.3.2](https://www.pcisecuritystandards.org/document_library/)

🇺🇸 NIST SP 800-53, [AC-4 Information Flow Enforcement](https://csrc.nist.gov/projects/cprt/catalog#/cprt/framework/version/SP_800_53_5_1_0/home?element=AC-4)

🇺🇸 NIST SP 800-53, [SC-7 Boundary Protection](https://csrc.nist.gov/projects/cprt/catalog#/cprt/framework/version/SP_800_53_5_1_0/home?element=SC-7)

✓✓ Out-of-band DNS Checks

⇄ Bidirectional TLS 1.2+ and SSH v2 Checks

---

## Reference Architectures

### Cross-Zone

In the `cross-zone` mode, the Gateway Load Balancer (GWLB) will distribute traffic evenly across all deployed AZs. This reduces the number of DiscrimiNAT Firewall instances you will have to run for high-availability but increases data-transfer costs.

> **Note**\
> Terraform variable `high_availability_mode` should be set to `cross-zone`. This is also the default.

> **Warning**\
> Minimum number of allocated Elastic IPs for high-availability (=2) with headroom for auto-scaling (+1) is **3 per region**.

![](https://chasersystems.com/img/gwlb-cross-zone-v2.drawio.png)

---

### Intra-Zone

In the `intra-zone` mode, the GWLB will distribute traffic evenly across all DiscrimiNAT Firewall instances in the same AZ as the client. For effective high-availability, this mode will need at least two instances per deployed AZ. Please note this does not fully protect you against the failure of an entire AZ on the Amazon side, however your other services in the zone would potentially be impacted too and therefore not sending egress traffic.

> **Note**\
> Terraform variable `high_availability_mode` should be set to `intra-zone`.

> **Warning**\
> Traffic will not be balanced to other zones, even in case of failure of all instances in one zone, therefore minimum high-availability numbers (=2) have to be configured per AZ.

> **Warning**\
> Minimum number of allocated Elastic IPs for high-availability (=2) with headroom for auto-scaling (+1) is **3 per AZ**; and therefore 6 for two AZs.

![](https://chasersystems.com/img/gwlb-intra-zone-v2.drawio.png)

---

## Elastic IPs

If a Public IP is not found attached to a DiscrimiNAT instance, it will look for any allocated but unassociated Elastic IPs that have a tag-key named `discriminat` (set to any value.) One of such Elastic IPs will be attempted to be associated with itself then.

> **Note**\
> This allows you to have a stable set of static IPs to share with your partners, who may wish to allowlist/whitelist them.

The IAM permissions needed to do this are already a part of this module. Specifically, they are:

```
ec2:DescribeAddresses
ec2:AssociateAddress
```

Additionally, these permissions are constrained to work only for resources tagged appropriately, i.e. the tag `discriminat` is not null.

```
"Condition": {
  "Null": {
    "aws:ResourceTag/discriminat": false
  }
}
```

> **Warning**\
> An EC2 VPC Endpoint is needed for this mechanism to work though – since making the association needs access to the EC2 API. In the deployment example below, this is demonstrated by deploying the endpoint along with the VPC.

---

## Other VPC Requirements

As noted in the Elastic IPs section above, an EC2 VPC Endpoint will be needed for DiscrimiNAT instances to associate an Elastic IP with themselves. This is demonstrated in the deployment example below.

---

## Deployment Examples

<details><summary>📜 Entirely new VPC with DiscrimiNAT filtering for Private Subnets</summary>

```hcl
# Allocating three Elastic IPs for high-availability and auto-scaling in the
# cross-zone mode.
resource "aws_eip" "nat" {
  count = 3

  tags = {
    "discriminat" : "some-comment",
    "Name" : "egress-ip-reserved"
  }

  lifecycle {
    # change to `true` if this IP address has been shared with third parties
    prevent_destroy = false
  }
}

# Deploying a new VPC in two AZs with Public and Private Subnets.
module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "> 3, < 6"

  name = "discriminat-example"

  cidr = "172.16.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  azs             = ["eu-west-2a", "eu-west-2b"]
  public_subnets  = ["172.16.11.0/24", "172.16.21.0/24"]
  private_subnets = ["172.16.12.0/24", "172.16.22.0/24"]

  map_public_ip_on_launch = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}

# Deploying an EC2 VPC Endpoint.
module "aws_vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "> 3, < 6"

  vpc_id = module.aws_vpc.vpc_id

  endpoints = {
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpce_ec2.id]
      subnet_ids          = module.aws_vpc.private_subnets
    }
  }

  tags = {
    "Name" : "ec2"
  }
}

# A Security Group that allows the entire VPC to use the EC2 VPC Endpoint.
resource "aws_security_group" "vpce_ec2" {
  name        = "vpce-ec2"
  description = "ingress from entire vpc to ec2 endpoint for connectivity to it without public ips"

  vpc_id = module.aws_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.aws_vpc.vpc_cidr_block]

    description = "only https standard port needed for ec2 api"
  }

  tags = {
    "Name" : "vpce-ec2"
  }
}

# Deploying DiscrimiNAT.
module "discriminat" {
  source = "ChaserSystems/discriminat-gwlb/aws"

  public_subnets  = module.aws_vpc.public_subnets
  private_subnets = module.aws_vpc.private_subnets

  # iam_get_additional_ssm_params = [
  #   "arn:aws:ssm:eu-west-2:000000000000:parameter/team1-list",
  #   "arn:aws:ssm:eu-west-2:111111111111:parameter/service1-list"
  # ]
  # iam_get_additional_secrets = [
  #   "arn:aws:secretsmanager:eu-west-2:000000000000:secret:service-a-allowed-egress-fqdns",
  #   "arn:aws:secretsmanager:eu-west-2:111111111111:secret:service-b-allowed-egress-fqdns"
  # ]

  preferences = <<EOF
  {
    "%default": {
      "flow_log_verbosity": "full",
      "see_thru": "2026-01-19"
    }
  }
  EOF

  depends_on = [module.aws_vpc_endpoints]
}

# Updating route tables of Private Subnets with Gateway Load Balancer Endpoint
# routes for Internet access.
resource "aws_route" "discriminat" {
  count = length(module.aws_vpc.private_subnets)

  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = module.discriminat.target_gwlb_endpoints[count.index].route_table_id
  vpc_endpoint_id        = module.discriminat.target_gwlb_endpoints[count.index].id
}
```
</details>

---

## Security Group Examples

<details><summary>📜 Simple example with two allowed HTTPS FQDNs</summary>

```hcl
# This Security Group must be associated with its intended, respective
# application – whether that is in EC2, Lambda, Fargate or EKS, etc. as long as
# a Security Group can be associated with it.

resource "aws_security_group" "foo" {
  # You could use a data source or get a reference from another resource for the
  # VPC ID.
  vpc_id = module.aws_vpc.vpc_id
}

resource "aws_security_group_rule" "saas_monitoring" {
  security_group_id = aws_security_group.foo.id

  type      = "egress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  # The DiscrimiNAT Firewall will apply its own checks anyway, so you could
  # choose to leave this wide open without worry.
  cidr_blocks = ["0.0.0.0/0"]

  # You could simply embed the allowed FQDNs, comma-separated, like below. Full
  # syntax at https://chasersystems.com/docs/discriminat/aws/config-ref
  description = "discriminat:tls:app.datadoghq.com,collector.newrelic.com"
}
```
</details>

<details><summary>📜 Complex example with HTTPS, SSH and two Security Groups</summary>

```hcl
locals {
  # You could store allowed FQDNs as a list...
  fqdns_sftp_banks = [
    "sftp.bank1.com",
    "sftp.bank2.com"
  ]
  fqdns_saas_auth = [
    "foo.auth0.com",
    "mtls.okta.com"
  ]
}

locals {
  # ...and format them into the expected syntax.
  discriminat_sftp_banks = format("discriminat:ssh:%s", join(",", local.fqdns_sftp_banks))
  discriminat_saas_auth  = format("discriminat:tls:%s", join(",", local.fqdns_saas_auth))
}

resource "aws_security_group" "bar" {
  # You could use a data source or get a reference from another resource for the
  # VPC ID.
  vpc_id = module.aws_vpc.vpc_id
}

resource "aws_security_group_rule" "saas_auth" {
  security_group_id = aws_security_group.bar.id

  type      = "egress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]

  # Use of FQDNs list formatted into the expected syntax.
  description = local.discriminat_saas_auth
}

resource "aws_security_group_rule" "sftp_banks" {
  security_group_id = aws_security_group.bar.id

  type        = "egress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  # Use of FQDNs list formatted into the expected syntax.
  description = local.discriminat_sftp_banks
}
```
</details>

---

## Allowlist Building Examples

<details><summary>📜 Allow and log everything uptil and inclusive of a certain date.</summary>

```hcl
# This Security Group must be associated with its intended, respective
# application – whether that is in EC2, Lambda, Fargate or EKS, etc. as long as
# a Security Group can be associated with it.

resource "aws_security_group" "monitor" {
  # You could use a data source or get a reference from another resource for the
  # VPC ID.
  vpc_id = module.aws_vpc.vpc_id
}

resource "aws_security_group_rule" "monitor_and_log" {
  security_group_id = aws_security_group.monitor.id

  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = ["0.0.0.0/0"]

  # The `see-thru` mode accepts a valid date in YYYY-mm-dd format. Full syntax
  # at https://chasersystems.com/docs/discriminat/aws/config-ref#see-thru-mode
  description = "discriminat:see-thru:2026-01-19"
}
```
</details>

Afterwards, with the Security Group ID of `monitor` at hand, go to CloudWatch -> Log Insights, select the `DiscrimiNAT` log group and execute the following query to get a list of all accessed FQDNs in a nicely formatted table.

> **Warning**\
> You will have to update the Security Group ID in this query.

```
filter see_thru_exerted AND see_thru_gid = "sg-00replaceme00"
| stats count() by see_thru_exerted, see_thru_gid, dhost, proto, dpt
```

![](https://chasersystems.com/img/log-insights-after-see-thru-log-capture.gif)

See our website for full documentation on [building an allowlist from scratch](https://chasersystems.com/docs/discriminat/aws/logs-ref#building-an-allowlist-from-scratch).

---

## More Help

* Contact our [DevSecOps Support](mailto:devsecops@chasersystems.com) for help and queries at any stage of your journey. You will be connected with a highly-skilled engineer from the first interaction.
* Check out the [full documentation on our website](https://chasersystems.com/docs/).

---

## Automated System Health Reporting

10 minutes after boot, a few minutes before 0200 UTC every day and once at shutdown, each instance of DiscrimiNAT will collect its OS internals & system logs since instance creation, config changes & traffic flow information from last two hours and upload it to a Chaser-owned cloud bucket. This information is encrypted at rest with a certain public key so only relevant individuals with access to the corresponding private key can decrypt it. The transfer is encrypted over TLS.

Access to this information is immensely useful to create a faster and more reliable DiscrimiNAT as we add new features. We also aim to learn about how users are interacting with the product in order to further improve the usability of it as they embark on a very ambitious journey of fully accounted for and effective egress controls.

We understand if certain environments within your deployment would rather not have this turned on. **To disable it,** a file at the path `/etc/chaser/disable_automated-system-health-reporting` should exist. From our Terraform module v2.7.1 onwards, this can be accomplished by setting the variable `ashr` to `false`:

```
ashr = false
```

--

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.2, < 2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.38, < 7 |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_preferences"></a> [preferences](#input\_preferences) | Default preferences. See docs at https://chasersystems.com/docs/discriminat/aws/default-prefs/ | `string` | `"{\n  \"%default\": {\n    \"wildcard_exposure\": \"prohibit_public_suffix\",\n    \"flow_log_verbosity\": \"full\",\n    \"see_thru\": null,\n    \"x509_crls\": \"ignore\"\n  }\n}\n"` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | The IDs of the Public Subnets to deploy the DiscrimiNAT Firewall instances in. These must have routing to the Internet via an Internet Gateway already. | `list(string)` | n/a | yes |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | The IDs of the Private Subnets where the workload, of which the egress is to be filtered, resides. A Gateway Load Balancer (GWLB) will be deployed in these, and a map of Private Subnets' Route Table IDs to VPC Endpoint IDs (GWLB) will be emitted in the `target_gwlb_endpoints` output field. | `list(string)` | n/a | yes |
| <a name="input_connection_draining_time"></a> [connection\_draining\_time](#input\_connection\_draining\_time) | In seconds, the amount of time to allow for existing flows to end naturally. During an instance-refresh or a scale-in activity, a DiscrimiNAT Firewall instance will not be terminated for at least this long to prevent abrupt interruption of existing flows. | `number` | `150` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of key-value tag pairs to apply to resources created by this module. See examples for use. | `map(any)` | `{}` | no |
| <a name="input_high_availability_mode"></a> [high\_availability\_mode](#input\_high\_availability\_mode) | `cross-zone` or `intra-zone`. In the `cross-zone` mode, the Gateway Load Balancer (GWLB) will distribute traffic evenly across all deployed AZs. This reduces the number of DiscrimiNAT Firewall instances you will have to run for high-availability but increases data-transfer costs. In the `intra-zone` mode, the GWLB will distribute traffic evenly across all DiscrimiNAT Firewall instances in the same AZ as the client. For effective high-availability, this mode will need at least two instances per deployed AZ. | `string` | `"cross-zone"` | no |
| <a name="input_per_region_min_instances"></a> [per\_region\_min\_instances](#input\_per\_region\_min\_instances) | In case of `high_availability_mode` set to `cross-zone`, this is the minimum number of instances across all AZs. This variable is IGNORED in case of `high_availability_mode` set to `intra-zone`. | `number` | `2` | no |
| <a name="input_per_region_max_instances"></a> [per\_region\_max\_instances](#input\_per\_region\_max\_instances) | In case of `high_availability_mode` set to `cross-zone`, this is the maximum number of instances across all AZs following a scale-out or an instances-refresh event. This variable is IGNORED in case of `high_availability_mode` set to `intra-zone`. | `number` | `3` | no |
| <a name="input_per_az_min_instances"></a> [per\_az\_min\_instances](#input\_per\_az\_min\_instances) | In case of `high_availability_mode` set to `intra-zone`, this is the minimum number of instances per AZ. This variable is IGNORED in case of `high_availability_mode` set to `cross-zone`. | `number` | `2` | no |
| <a name="input_per_az_max_instances"></a> [per\_az\_max\_instances](#input\_per\_az\_max\_instances) | In case of `high_availability_mode` set to `intra-zone`, this is the maximum number of instances per AZ following a scale-out or an instances-refresh event. This variable is IGNORED in case of `high_availability_mode` set to `cross-zone`. | `number` | `3` | no |
| <a name="input_instance_size"></a> [instance\_size](#input\_instance\_size) | The default of `t3.small` should suffice for light to medium levels of usage. Anything less than 2 CPU cores and 2 GB of RAM is not recommended. For faster access to the Internet and for accounts with a large number of VMs, you may want to choose a machine type with dedicated CPU cores. Valid values are `t3.small` , `c6i.large` , `c6i.xlarge` , `c6a.large` , `c6a.xlarge` . | `string` | `"t3.small"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Strongly suggested to leave this to the default, that is to NOT associate any key-pair with the instances. In case SSH access is desired, provide the name of a valid EC2 Key Pair. | `string` | `null` | no |
| <a name="input_user_data_base64"></a> [user\_data\_base64](#input\_user\_data\_base64) | Strongly suggested to NOT run custom startup scripts on DiscrimiNAT Firewall instances. But if you had to, supply a base64 encoded version here. | `string` | `null` | no |
| <a name="input_ami_owner"></a> [ami\_owner](#input\_ami\_owner) | Reserved for use with Chaser support. Allows overriding the source AMI account for the DiscrimiNAT Firewall instances. | `string` | `"aws-marketplace"` | no |
| <a name="input_ami_version"></a> [ami\_version](#input\_ami\_version) | Reserved for use with Chaser support. Allows overriding the source AMI version for DiscrimiNAT Firewall instances. | `string` | `"2.20"` | no |
| <a name="input_ami_auto_update"></a> [ami\_auto\_update](#input\_ami\_auto\_update) | Automatically look up and use the latest version of DiscrimiNAT image available from `ami_owner`. When this is set to `true`, `ami_version` is ignored. | `bool` | `true` | no |
| <a name="input_iam_get_additional_ssm_params"></a> [iam\_get\_additional\_ssm\_params](#input\_iam\_get\_additional\_ssm\_params) | A list of additional SSM Parameters' full ARNs to apply the `ssm:GetParameter` Action to in the IAM Role for DiscrimiNAT. This is useful if an allowlist referred in a Security Group lives in one and is separately managed. `arn:aws:ssm:*:*:parameter/DiscrimiNAT*` is always included. | `list(string)` | `[]` | no |
| <a name="input_iam_get_additional_secrets"></a> [iam\_get\_additional\_secrets](#input\_iam\_get\_additional\_secrets) | A list of additional Secrets' full ARNs (in Secrets Manager) to apply the `secretsmanager:GetSecretValue` Action to in the IAM Role for DiscrimiNAT. This is useful if an allowlist referred in a Security Group lives in one and is separately managed. | `list(string)` | `[]` | no |
| <a name="input_byol"></a> [byol](#input\_byol) | If using the BYOL version from the marketplace, supply the licence key as supplied by Chaser Systems here. | `string` | `null` | no |
| <a name="input_ashr"></a> [ashr](#input\_ashr) | Automated System Health Reporting. See note in README to learn more. Set to false to disable. Default is true and hence enabled. | `bool` | `true` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the CloudWatch Log Group where DiscrimiNAT instances will log traffic flow and configuration changes. Useful for automating any logging routing configuration. |
| <a name="output_target_gwlb_endpoints"></a> [target\_gwlb\_endpoints](#output\_target\_gwlb\_endpoints) | Map of Route Table IDs to VPC Endpoint IDs (Gateway Load Balancer) for setting as targets to 0.0.0.0/0 in routing tables of the Private Subnets. A Terraform example of using these in an `aws_route` resource can be found at https://github.com/ChaserSystems/terraform-aws-discriminat-gwlb#deployment-examples, under 'Entirely new VPC with DiscrimiNAT filtering for Private Subnets' |
## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.discriminat_wait_for_drain_and_warmup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_autoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_iam_instance_profile.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.preferences](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_endpoint.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint_service.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service) | resource |
| [aws_ami.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_eips.discriminat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eips) | data source |
| [aws_route_table.private_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_table) | data source |
| [aws_subnet.public_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.context](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
<!-- END_TF_DOCS -->
