# Shown after apply and by `make output`.
output "vpc_id" {
  description = "ID of the Slurm VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the Slurm VPC."
  value       = aws_vpc.this.cidr_block
}
