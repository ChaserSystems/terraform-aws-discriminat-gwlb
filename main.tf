resource "aws_security_group" "discriminat" {
  name_prefix = "discriminat-"
  description = "firewall rules for the DiscrimiNAT Firewall instances themselves, NOT for clients and applications"
  lifecycle {
    create_before_destroy = true
  }

  vpc_id = data.aws_vpc.context.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.context.cidr_block]
    description = "internet-bound TCP connections from any host in the VPC"
  }

  ingress {
    from_port   = 1042
    to_port     = 1042
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.context.cidr_block]
    description = "health check service"
  }

  ingress {
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.context.cidr_block]
    description = "GENEVE encapsulation receive port from GWLB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DiscrimiNAT Firewall itself to internet forwarding on behalf of other hosts"
  }

  tags = local.tags
}

resource "aws_launch_template" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  update_default_version = true
  image_id               = data.aws_ami.discriminat.id
  instance_type          = var.instance_size

  iam_instance_profile {
    name = aws_iam_instance_profile.discriminat.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = data.aws_ami.discriminat.root_device_name
    ebs {
      encrypted   = true
      volume_size = tolist(data.aws_ami.discriminat.block_device_mappings)[0].ebs.volume_size
      volume_type = "gp3"
    }
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.discriminat.id]
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { "discriminat" : "self-manage" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  key_name  = var.key_pair_name
  user_data = var.user_data_base64

  tags = local.tags
}

resource "aws_autoscaling_group" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
    precondition {
      condition     = length(data.aws_eips.discriminat.public_ips) >= local.max_possible_instances
      error_message = "Allocated (and tagged) Elastic IPs (EIPs) must be equal to or greater than maximum possible number of DiscrimiNAT Firewall instances. The EIPs must be tagged with key `discriminat` in lowercase."
    }
  }

  vpc_zone_identifier = var.public_subnets

  target_group_arns = [aws_lb_target_group.discriminat.arn]

  max_size         = var.high_availability_mode == "cross-zone" ? var.per_region_max_instances : length(var.public_subnets) * var.per_az_max_instances
  min_size         = var.high_availability_mode == "cross-zone" ? var.per_region_min_instances : length(var.public_subnets) * var.per_region_min_instances
  desired_capacity = var.high_availability_mode == "cross-zone" ? var.per_region_min_instances : length(var.public_subnets) * var.per_region_min_instances

  default_cooldown = 1

  health_check_grace_period = 0
  health_check_type         = "ELB"
  enabled_metrics           = ["GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

  launch_template {
    name    = aws_launch_template.discriminat.name
    version = aws_launch_template.discriminat.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  termination_policies = ["OldestInstance"]

  dynamic "tag" {
    for_each = local.tags
    iterator = i
    content {
      key                 = i.key
      value               = i.value
      propagate_at_launch = false
    }
  }
}


resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu"
  autoscaling_group_name = aws_autoscaling_group.discriminat.name

  cooldown = 0
  estimated_instance_warmup = (
    var.connection_draining_time +
    local.delay_2_shutdown_drained +
    local.delay_3_eip_dissociation +
    local.delay_4_cache_priming
  )
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    disable_scale_in = false
    target_value     = 20
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

resource "aws_autoscaling_lifecycle_hook" "discriminat_wait_for_drain_and_warmup" {
  name = "wait-for-drain-and-warmup"

  autoscaling_group_name = aws_autoscaling_group.discriminat.name

  default_result       = "CONTINUE"
  lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"

  heartbeat_timeout = (
    var.connection_draining_time +
    local.delay_2_shutdown_drained +
    local.delay_3_eip_dissociation +
    local.delay_4_cache_priming
  )
}

resource "aws_lb_target_group" "discriminat" {
  name_prefix = "discr-"
  lifecycle {
    create_before_destroy = true
  }

  vpc_id = data.aws_vpc.context.id

  port     = 6081
  protocol = "GENEVE"

  deregistration_delay = var.connection_draining_time

  target_failover {
    on_deregistration = "no_rebalance"
    on_unhealthy      = "no_rebalance"
  }

  health_check {
    healthy_threshold   = 2
    interval            = 5
    port                = 1042
    timeout             = 2
    unhealthy_threshold = 2
  }

  tags = local.tags
}

resource "aws_lb" "discriminat" {
  name_prefix = "discr-"
  lifecycle {
    create_before_destroy = true
  }

  load_balancer_type = "gateway"
  subnets            = var.private_subnets

  enable_cross_zone_load_balancing = var.high_availability_mode == "cross-zone" ? true : false

  tags = local.tags
}

resource "aws_lb_listener" "discriminat" {
  load_balancer_arn = aws_lb.discriminat.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.discriminat.arn
  }

  tags = local.tags
}
