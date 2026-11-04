# Alerting and cost guardrails:
#   - SNS topic that emails you
#   - EventBridge rule: any Batch job in the platform's queues that FAILS -> email
#   - Monthly AWS Budget: email at 80% forecast and 100% actual
#   - CloudWatch dashboard: job outcomes, data volume, spend

data "aws_region" "current" {}

resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:EventBridge cannot publish to a topic encrypted with the AWS-managed SNS key; alerts carry job names only, no genomic data.
  name = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "aws_iam_policy_document" "alerts" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

resource "aws_cloudwatch_event_rule" "job_failed" {
  name        = "${var.name}-batch-job-failed"
  description = "A Batch job in a platform queue failed"
  event_pattern = jsonencode({
    source        = ["aws.batch"]
    "detail-type" = ["Batch Job State Change"]
    detail = {
      status   = ["FAILED"]
      jobQueue = var.job_queue_arns
    }
  })
}

resource "aws_cloudwatch_event_target" "job_failed_email" {
  rule = aws_cloudwatch_event_rule.job_failed.name
  arn  = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      job    = "$.detail.jobName"
      reason = "$.detail.statusReason"
      queue  = "$.detail.jobQueue"
    }
    input_template = "\"Batch job <job> failed in <queue>. Reason: <reason>. See runbook: docs/runbook.md#a-batch-job-failed\""
  }
}

resource "aws_cloudwatch_event_rule" "job_succeeded" {
  # Counted on the dashboard only; no email.
  name = "${var.name}-batch-job-succeeded"
  event_pattern = jsonencode({
    source        = ["aws.batch"]
    "detail-type" = ["Batch Job State Change"]
    detail = {
      status   = ["SUCCEEDED"]
      jobQueue = var.job_queue_arns
    }
  })
}

resource "aws_cloudwatch_log_group" "job_events" {
  # EventBridge only delivers to log groups under /aws/events/.
  name              = "/aws/events/${var.name}-batch-job-events"
  retention_in_days = 30
}

data "aws_iam_policy_document" "events_to_logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.job_events.arn}:*"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "delivery.logs.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "events_to_logs" {
  policy_name     = "${var.name}-events-to-logs"
  policy_document = data.aws_iam_policy_document.events_to_logs.json
}

resource "aws_cloudwatch_event_target" "job_succeeded_log" {
  rule = aws_cloudwatch_event_rule.job_succeeded.name
  arn  = aws_cloudwatch_log_group.job_events.arn
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "${var.name}-platform"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Batch jobs: failed vs succeeded"
          region = data.aws_region.current.name
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/Events", "TriggeredRules", "RuleName", aws_cloudwatch_event_rule.job_failed.name, { label = "Failed" }],
            ["AWS/Events", "TriggeredRules", "RuleName", aws_cloudwatch_event_rule.job_succeeded.name, { label = "Succeeded" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Stored data (bytes, daily)"
          region = data.aws_region.current.name
          stat   = "Average"
          period = 86400
          metrics = [
            for k, b in var.bucket_names :
            ["AWS/S3", "BucketSizeBytes", "BucketName", b, "StorageType", "StandardStorage", { label = k }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Estimated month-to-date charges (USD)"
          region = "us-east-1" # billing metrics only exist here
          stat   = "Maximum"
          period = 21600
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"],
          ]
        }
      },
    ]
  })
}
