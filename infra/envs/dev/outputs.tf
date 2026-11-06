output "region" {
  value = var.region
}

output "data_bucket" {
  value = module.storage.bucket_names["data"]
}

output "results_bucket" {
  value = module.storage.bucket_names["results"]
}

output "work_bucket" {
  value = module.storage.bucket_names["work"]
}

output "spot_queue" {
  value = module.batch.spot_queue_name
}

output "ondemand_queue" {
  value = module.batch.ondemand_queue_name
}

output "dashboard" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${module.observability.dashboard_name}"
}

output "alerts_topic_arn" {
  value = module.observability.alerts_topic_arn
}