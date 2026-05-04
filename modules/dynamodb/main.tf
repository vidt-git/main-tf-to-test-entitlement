# Copyright IBM Corp. 2025, 2026

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:table/example"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "table/example"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
  step_scaling_policy_configuration {}
  target_tracking_scaling_policy_configuration {
    disable_scale_in = false
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
      resource_label         = null
    }

    target_value       = 75
    scale_in_cooldown  = null
    scale_out_cooldown = null
  }
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  name               = "DynamoDBWriteCapacityUtilization:table/example"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "table/example"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
  step_scaling_policy_configuration {}
  target_tracking_scaling_policy_configuration {
    disable_scale_in = false
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
      resource_label         = null
    }
    scale_in_cooldown  = null
    scale_out_cooldown = null
    target_value       = 70
  }
}

resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/example"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
  tags               = null
}


resource "aws_appautoscaling_target" "dynamodb_table_write_target" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/example"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
  tags               = null
}

resource "aws_dynamodb_table" "my_table" {
  name             = "example"
  billing_mode     = "PROVISIONED"
  read_capacity    = 1
  write_capacity   = 1
  hash_key         = "TestTableHashKey"
  range_key        = null
  stream_view_type = "NEW_AND_OLD_IMAGES"
  stream_enabled   = true
  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "TestTableHashKey"
    type = "S"
  }

  tags = null
}