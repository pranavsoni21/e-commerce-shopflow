output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnets_id" {
  value = [for s in aws_subnet.public_subnet : s.id]
}

output "private_subnets_id" {
  value = [for s in aws_subnet.private_subnet : s.id]
}