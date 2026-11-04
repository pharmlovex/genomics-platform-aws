output "spot_queue_name" {
  value = aws_batch_job_queue.spot.name
}

output "spot_queue_arn" {
  value = aws_batch_job_queue.spot.arn
}

output "ondemand_queue_name" {
  value = aws_batch_job_queue.ondemand.name
}

output "job_log_group" {
  value = aws_cloudwatch_log_group.batch_jobs.name
}
