provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {}
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config  = "${var.vpc_state_config}"
}

data "aws_ami" "amazon_linux2" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.tpl")}"

  vars {
    name = "${var.name}"
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.name}_role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "bastion_cloudwatch_agent" {
  role       = "${aws_iam_role.bastion.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-profile"
  role = "${aws_iam_role.bastion.name}"
}

resource "aws_ssm_parameter" "cloudwatch_agent" {
  name      = "AmazonCloudWatch-Agent-${var.name}"
  type      = "String"
  value     = "${file("${path.module}/cloudwatch_agent.json")}"
  overwrite = true
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}"
  description = "Security group for ${var.name}"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.trusted_cidr_blocks}"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${var.trusted_cidr_blocks}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  count = "${var.instance_count}"

  ami                    = "${data.aws_ami.amazon_linux2.image_id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${element(data.terraform_remote_state.vpc.public_subnets, count.index % length(data.terraform_remote_state.vpc.public_subnets))}"
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  key_name               = "${var.key_name}"
  monitoring             = false
  user_data              = "${data.template_file.user_data.rendered}"
  iam_instance_profile   = "${aws_iam_instance_profile.bastion.name}"

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 8
  }

  tags {
    "Name"        = "${var.instance_count > 1 ? format("%s-%d", var.name, count.index+1) : var.name}"
    "Environment" = "${var.environment}"
  }

  volume_tags {
    "Name"        = "${var.instance_count > 1 ? format("%s-%d", var.name, count.index+1) : var.name}"
    "Environment" = "${var.environment}"
  }

//  lifecycle {
//    ignore_changes = [
//      "ami",
//      "instance_type",
//      "ebs_optimized",
//      "root_block_device",
//      "ebs_block_device",
//      "user_data",
//    ]
//  }
}

resource "aws_eip" "eip" {
  count = "${var.instance_count}"

  instance = "${aws_instance.bastion.*.id[count.index]}"
  vpc      = true
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = "${var.instance_count}"

  alarm_name          = "${format("%s-CPUUtilization", element(aws_instance.bastion.*.tags.Name, count.index))}"
  alarm_description   = "${format("%s-CPUUtilization", element(aws_instance.bastion.*.tags.Name, count.index))}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    InstanceId = "${aws_instance.bastion.*.id[count.index]}"
  }

//  alarm_actions = ["${var.topick_arn}"]
//  ok_actions    = ["${var.topick_arn}"]
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  count = "${var.instance_count}"

  alarm_name          = "${format("%s-mem_used_percent", element(aws_instance.bastion.*.tags.Name, count.index))}"
  alarm_description   = "${format("%s-mem_used_percent", element(aws_instance.bastion.*.tags.Name, count.index))}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    InstanceId = "${aws_instance.bastion.*.id[count.index]}"
  }

//  alarm_actions = ["${var.topick_arn}"]
//  ok_actions    = ["${var.topick_arn}"]
}

resource "aws_cloudwatch_metric_alarm" "disk" {
  count = "${var.instance_count}"

  alarm_name          = "${format("%s-disk_used_percent", element(aws_instance.bastion.*.tags.Name, count.index))}"
  alarm_description   = "${format("%s-disk_used_percent", element(aws_instance.bastion.*.tags.Name, count.index))}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    path       = "/"
    InstanceId = "${aws_instance.bastion.*.id[count.index]}"
    device     = "xvda1"
    fstype     = "xfs"
  }

//  alarm_actions = ["${var.topick_arn}"]
//  ok_actions    = ["${var.topick_arn}"]
}
