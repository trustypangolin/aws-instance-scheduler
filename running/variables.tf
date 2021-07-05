variable "resource_prefix" {
  type        = string
  description = "resource prefix"
}

variable "tags" {
  description = "Tags to set on the resources."
  type = map(string)
}

variable "deadletter" {
  type = string
  description = "deadletter SNS arn for lambda functions"
}

variable "issuestopic" {
  type = string
  description = "SNS Topic arn"
}

variable "aws_target_regions" {
  type = string
  description = "region endpoints csv format"
}

variable "aws_target_accounts" {
  type = string
  description = "Target AWS Accounts csv format"
}