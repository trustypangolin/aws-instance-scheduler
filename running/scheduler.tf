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
          "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/Solutions/aws-instance-scheduler/UUID/*"
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

resource "aws_lambda_function" "aws_scheduler_scheduler_function" {
  function_name = "${var.resource_prefix}aws_scheduler"
  description   = "schedule EC2 and RDS instances"
  s3_bucket     = "solutions-${data.aws_region.current.name}"
  s3_key        = "aws-instance-scheduler/v1.4.0/instance-scheduler.zip"
  dead_letter_config {
    target_arn = var.deadletter
  }
  handler = "aws_scheduler_scheduler_function.lambda_handler"
  runtime = "python3.8"
  timeout = 900
  role    = aws_iam_role.scheduler_role.arn
  environment {
    variables = {
      ACCOUNT = var.aws_target_accounts
      BOTO_RETRY = "5,10,30,0.25"
      CONFIG_TABLE = aws_dynamodb_table.config-table.name
      DDB_TABLE_NAME = aws_dynamodb_table.state-table.name
      ENABLE_SSM_MAINTENANCE_WINDOWS = "false"
      ENV_BOTO_RETRY_LOGGING = "FALSE"
      ISSUES_TOPIC_ARN = var.issuestopic
      LOG_GROUP = aws_cloudwatch_log_group.aws_instance_scheduler.name
      MAINTENANCE_WINDOW_TABLE = aws_dynamodb_table.maintenance-window-table.name
      METRICS_URL = "https://metrics.awssolutionsbuilder.com/generic"
      REGIONS = var.aws_target_regions
      SCHEDULER_FREQUENCY = "5"
      SEND_METRICS = "False"
      SOLUTION_ID = "S00030"
      START_EC2_BATCH_SIZE = 5
      STATE_TABLE = aws_dynamodb_table.state-table.name
      TAG_NAME = "Schedule"
      TRACE = "FALSE"
      USER_AGENT = "InstanceScheduler-aws-scheduler-140-v1.4.0"
      USER_AGENT_EXTRA = "AwsSolution/SO0030/v1.4.0"
      UUID_KEY = "/Solutions/aws-instance-scheduler/UUID/"
    }
  }
  tags = var.tags
}

# -- Function execution
#--------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "aws_scheduler_scheduler_event_rule" {
  name        = "${var.resource_prefix}aws-scheduler-scheduler-event-rule"
  description = "	Instance Scheduler - Rule to trigger instance for scheduler function version v1.4.0"
  schedule_expression = "rate(5 minutes)"
  is_enabled = true
}

resource "aws_cloudwatch_event_target" "aws_scheduler_scheduler_function" {
  rule      = aws_cloudwatch_event_rule.aws_scheduler_scheduler_event_rule.name
  target_id = "Function"
  arn       = aws_lambda_function.aws_scheduler_scheduler_function.arn
}

# -- Function logging
#--------------------------------------------------------------------------------------------------
resource "aws_lambda_permission" "aws_scheduler_scheduler_allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aws_scheduler_scheduler_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_target.aws_scheduler_scheduler_function.arn
}