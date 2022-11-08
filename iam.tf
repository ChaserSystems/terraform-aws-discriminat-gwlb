resource "aws_iam_policy" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:DiscrimiNAT:log-stream:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeAddresses"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:ModifyInstanceAttribute",
        "ec2:AssociateAddress"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:ResourceTag/discriminat": false
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "discriminat" {
  role       = aws_iam_role.discriminat.name
  policy_arn = aws_iam_policy.discriminat.arn
}

resource "aws_iam_instance_profile" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  role = aws_iam_role.discriminat.name
}
