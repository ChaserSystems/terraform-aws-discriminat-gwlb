variable "public_subnets" {
  type        = list(string)
  description = "The IDs of the Public Subnets to deploy the DiscrimiNAT Firewall instances in. These must have routing to the Internet via an Internet Gateway already."
}

variable "private_subnets" {
  type        = list(string)
  description = "The IDs of the Private Subnets where the workload, of which the egress is to be filtered, resides. A Gateway Load Balancer (GWLB) will be deployed in these, and a map of Private Subnets' Route Table IDs to VPC Endpoint IDs (GWLB) will be emitted in the `target_gwlb_endpoints` output field."
}

variable "connection_draining_time" {
  type        = number
  description = "In seconds, the amount of time to allow for existing flows to end naturally. During an instance-refresh or a scale-in activity, a DiscrimiNAT Firewall instance will not be terminated for at least this long to prevent abrupt interruption of existing flows."
  default     = 150

  validation {
    condition     = var.connection_draining_time >= 150
    error_message = "Variable `connection_draining_time` must be set to at least 150 seconds. In practice, the Gateway Load Balancer (GWLB) takes at least this long to stop sending traffic to an instance marked for removal from load balancing."
  }
}

variable "tags" {
  type        = map(any)
  description = "Map of key-value tag pairs to apply to resources created by this module. See examples for use."
  default     = {}
}

variable "high_availability_mode" {
  type        = string
  description = "`cross-zone` or `intra-zone`. In the `cross-zone` mode, the Gateway Load Balancer (GWLB) will distribute traffic evenly across all deployed AZs. This reduces the number of DiscrimiNAT Firewall instances you will have to run for high-availability but increases data-transfer costs. In the `intra-zone` mode, the GWLB will distribute traffic evenly across all DiscrimiNAT Firewall instances in the same AZ as the client. For effective high-availability, this mode will need at least two instances per deployed AZ."
  default     = "cross-zone"

  validation {
    condition     = contains(["cross-zone", "intra-zone"], var.high_availability_mode)
    error_message = "Variable `high_availability_mode` must be set to either `cross-zone` or `intra-zone`."
  }
}

variable "per_region_min_instances" {
  type        = number
  description = "In case of `high_availability_mode` set to `cross-zone`, this is the minimum number of instances across all AZs. This variable is IGNORED in case of `high_availability_mode` set to `intra-zone`."
  default     = 2
}

variable "per_region_max_instances" {
  type        = number
  description = "In case of `high_availability_mode` set to `cross-zone`, this is the maximum number of instances across all AZs following a scale-out or an instances-refresh event. This variable is IGNORED in case of `high_availability_mode` set to `intra-zone`."
  default     = 3
}

variable "per_az_min_instances" {
  type        = number
  description = "In case of `high_availability_mode` set to `intra-zone`, this is the minimum number of instances per AZ. This variable is IGNORED in case of `high_availability_mode` set to `cross-zone`."
  default     = 2
}

variable "per_az_max_instances" {
  type        = number
  description = "In case of `high_availability_mode` set to `intra-zone`, this is the maximum number of instances per AZ following a scale-out or an instances-refresh event. This variable is IGNORED in case of `high_availability_mode` set to `cross-zone`."
  default     = 3
}

variable "instance_size" {
  type        = string
  description = "The default of `t3.small` should suffice for light to medium levels of usage. Anything less than 2 CPU cores and 2 GB of RAM is not recommended. For faster access to the Internet and for accounts with a large number of VMs, you may want to choose a machine type with dedicated CPU cores. Valid values are `t3.small` , `c6i.large` , `c6i.xlarge` , `c6a.large` , `c6a.xlarge` ."
  default     = "t3.small"

  validation {
    condition     = contains(["t3.small", "c6i.large", "c6i.xlarge", "c6a.large", "c6a.xlarge"], var.instance_size)
    error_message = "Variable `instance_size` must be set to one of `t3.small` , `c6i.large` , `c6i.xlarge` , `c6a.large` , `c6a.xlarge` ."
  }
}

variable "key_pair_name" {
  type        = string
  description = "Strongly suggested to leave this to the default, that is to NOT associate any key-pair with the instances. In case SSH access is desired, provide the name of a valid EC2 Key Pair."
  default     = null
}

variable "user_data_base64" {
  type        = string
  description = "Strongly suggested to NOT run custom startup scripts on DiscrimiNAT Firewall instances. But if you had to, supply a base64 encoded version here."
  default     = null
}

variable "ami_owner" {
  type        = string
  description = "Reserved for use with Chaser support. Allows overriding the source AMI account for the DiscrimiNAT Firewall instances."
  default     = null
}

variable "ami_name" {
  type        = string
  description = "Reserved for use with Chaser support. Allows overriding the source AMI version for the DiscrimiNAT Firewall instances."
  default     = null
}

variable "byol" {
  type        = string
  sensitive   = true
  default     = null
  description = "If using the BYOL version from the marketplace, supply the licence key as supplied by Chaser Systems here."
}

variable "ashr" {
  type        = bool
  default     = true
  description = "Automated System Health Reporting. See note in README to learn more. Set to false to disable. Default is true and hence enabled."
}
