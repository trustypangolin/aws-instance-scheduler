data "aws_caller_identity" "remote" {}
data "aws_partition" "remote" {}

data "aws_iam_policy_document" "scheduler_remote_role" {
  statement {
    actions = [
      "rds:DeleteDBSnapshot",
      "rds:DescribeDBSnapshots",
      "rds:StopDBInstance"
    ]
    effect  =  "Allow"
    resources = [
      "arn:${data.aws_partition.remote.partition}:rds:*:${data.aws_caller_identity.remote.account_id}:snapshot:*"
    ]
  }
  statement {
    actions = [
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
      "rds:DescribeDBSnapshots",
      "rds:StartDBInstance",
      "rds:StopDBInstance"
    ]
    effect  =  "Allow"
    resources = [
      "arn:${data.aws_partition.remote.partition}:rds:*:${data.aws_caller_identity.remote.account_id}:db:*"
    ]
  }
}

data "aws_iam_policy_document" "assume-role-policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "AWS"
      identifiers = [
        var.aws_account_id.running
      ]
    }
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler_remote_role" {
  name               = "${var.resource_prefix}SchedulerRemoteRole"
  assume_role_policy = data.aws_iam_policy_document.assume-role-policy.json
  inline_policy {
    name = "SchedulerRemotePolicy" 
    policy = data.aws_iam_policy_document.scheduler_remote_role.json
  }
  tags               = var.tags
}
