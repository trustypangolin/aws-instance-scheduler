# =============== variables ===========================================
variable "aws_primary_region" {
  type        = string
  description = "AWS region to operate in."
}

variable "tags" {
  description = "Tags to set on the resources."
  type = map(string)
}

