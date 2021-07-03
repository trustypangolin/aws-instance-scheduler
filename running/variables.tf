# =============== variables ===========================================
variable "aws_primary_region" {
  type        = string
  description = "AWS region to operate in."
}

variable "resource_prefix" {
  type        = string
  description = "resource prefix"
}

variable "tags" {
  description = "Tags to set on the resources."
  type = map(string)
}

variable "aws_account_id" {
  description = "Accounts for solution"
  type = map(string)
}

