output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR assigned to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs ordered by availability zone."
  value       = [for zone in local.availability_zones : aws_subnet.public[zone].id]
}

output "private_subnet_ids" {
  description = "Application subnet IDs ordered by availability zone."
  value       = [for zone in local.availability_zones : aws_subnet.private[zone].id]
}

output "database_subnet_ids" {
  description = "Database subnet IDs ordered by availability zone."
  value       = [for zone in local.availability_zones : aws_subnet.database[zone].id]
}