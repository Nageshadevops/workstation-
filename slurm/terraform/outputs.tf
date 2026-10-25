# Shown after apply and by `make output`.
output "vpc_id" {
  description = "ID of the Slurm VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the Slurm VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet."
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway."
  value       = aws_nat_gateway.this.id
}

output "nat_public_ip" {
  description = "Elastic IP of the NAT gateway: the internet sees the Slurm servers as this address."
  value       = aws_eip.nat.public_ip
}

output "private_route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}

output "peering_connection_id" {
  description = "ID of the VPC peering connection to workstation-vpc."
  value       = aws_vpc_peering_connection.workstation.id
}

output "workstation_route_table_id" {
  description = "Existing workstation route table that got the route to 172.21.0.0/16."
  value       = data.aws_route_table.workstation.id
}
