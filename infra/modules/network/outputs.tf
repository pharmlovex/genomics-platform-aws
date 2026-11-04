output "vpc_id" {
  value = aws_vpc.this.id
}

output "compute_subnet_ids" {
  description = "Private subnets when NAT is on, public subnets otherwise."
  value       = var.enable_nat ? aws_subnet.private[*].id : aws_subnet.public[*].id
}

output "compute_security_group_id" {
  value = aws_security_group.compute.id
}
