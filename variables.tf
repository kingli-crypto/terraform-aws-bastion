variable "region" {
  description = "A region for the VPC"
}

variable "vpc_state_config" {
  description = "A config for accessing the vpc state file"
  type        = "map"
}

variable "name" {
  description = "Name to be used on all resources as prefix"
  default     = ""
}

variable "instance_count" {
  description = "Number of instances to launch"
  default     = 1
}

variable "instance_type" {
  description = "The type of instance to start"
}

variable "key_name" {
  description = "The key name to use for the instance"
  default     = ""
}

variable "environment" {
  description = "The environment to use for the instance"
  default     = ""
}

variable "trusted_cidr_blocks" {
  description = "A list of CIDR blocks to access instances"
  type        = "list"
}

variable "topick_arn" {
  description = "The topic of SNS for CloudWatch Alerm"
  default     = ""
}
