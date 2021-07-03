resource "aws_cloudwatch_log_group" "aws_instance_scheduler" {
  name = "/aws/${var.resource_prefix}AWS_Instance_Scheduler"
  retention_in_days = 3
  tags = var.tags
}

resource "aws_dynamodb_table" "state-table" {
  name           = "${var.resource_prefix}Scheduler_StateTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "service"
  range_key      = "account-region"

  server_side_encryption {
    enabled = true
  }

  attribute {
    name = "service"
    type = "S"
  }

  attribute {
    name = "account-region"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "config-table" {
  name           = "${var.resource_prefix}Scheduler_ConfigTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "type"
  range_key      = "name"

  server_side_encryption {
    enabled = true
  }

  attribute {
    name = "type"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "maintenance-window-table" {
  name           = "${var.resource_prefix}Scheduler_MaintenanceWindowTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "name"
  range_key      = "account-region"

  server_side_encryption {
    enabled = true
  }

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "account-region"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table_item" "config-schedule" {
  table_name = aws_dynamodb_table.config-table.name
  hash_key   = aws_dynamodb_table.config-table.hash_key
  range_key  = aws_dynamodb_table.config-table.range_key
  item = file("./dynamodb-json/scheduler.json")
}

resource "aws_dynamodb_table_item" "period-weekdays" {
  table_name = aws_dynamodb_table.config-table.name
  hash_key   = aws_dynamodb_table.config-table.hash_key
  range_key  = aws_dynamodb_table.config-table.range_key
  item = file("./dynamodb-json/period-weekdays.json")
}

resource "aws_dynamodb_table_item" "period-weekend" {
  table_name = aws_dynamodb_table.config-table.name
  hash_key   = aws_dynamodb_table.config-table.hash_key
  range_key  = aws_dynamodb_table.config-table.range_key
  item = file("./dynamodb-json/period-weekend.json")
}

resource "aws_dynamodb_table_item" "schedule-sydney" {
  table_name = aws_dynamodb_table.config-table.name
  hash_key   = aws_dynamodb_table.config-table.hash_key
  range_key  = aws_dynamodb_table.config-table.range_key
  item = file("./dynamodb-json/schedule-sydney.json")
}

resource "aws_dynamodb_table_item" "schedule-brisbane" {
  table_name = aws_dynamodb_table.config-table.name
  hash_key   = aws_dynamodb_table.config-table.hash_key
  range_key  = aws_dynamodb_table.config-table.range_key
  item = file("./dynamodb-json/schedule-brisbane.json")
}

resource "aws_dynamodb_table_item" "schedule-sydney-so" {
  table_name = aws_dynamodb_table.config-table.name
  hash_key   = aws_dynamodb_table.config-table.hash_key
  range_key  = aws_dynamodb_table.config-table.range_key
  item = file("./dynamodb-json/schedule-sydney-stop.json")
}

resource "aws_dynamodb_table_item" "schedule-brisbane-so" {
  table_name = aws_dynamodb_table.config-table.name
  hash_key   = aws_dynamodb_table.config-table.hash_key
  range_key  = aws_dynamodb_table.config-table.range_key
  item = file("./dynamodb-json/schedule-brisbane-stop.json")
}

data "aws_iam_policy_document" "scheduler_role" {
  statement {
      actions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
      effect    = "Allow"
      resources = ["*"]
    }

  statement {
      actions = [
        "dynamodb:BatchGetItem",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:Query",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:ConditionCheckItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ]
      effect =  "Allow"
      resources = [
        aws_dynamodb_table.state-table.arn
      ]
  }

  statement {
      actions = [
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem"
      ]
      effect =  "Allow"
      resources = [
        aws_dynamodb_table.config-table.arn,
        aws_dynamodb_table.maintenance-window-table.arn
      ]
  }

  statement {
      actions = [
          "ssm:PutParameter",
          "ssm:GetParameter"
      ]
      effect =  "Allow"
      resources = [
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_primary_region}:${var.aws_account_id.running}:parameter/Solutions/aws-instance-scheduler/UUID/*"
      ]
  }
}

resource "aws_iam_role" "scheduler_role" {
  name = "${var.resource_prefix}SchedulerRole"
  assume_role_policy = file("./json-iam-policy/trust.json")
  inline_policy {
    name = "SchedulerPolicy" 
    policy = data.aws_iam_policy_document.scheduler_role.json
  }
  tags = var.tags
}

