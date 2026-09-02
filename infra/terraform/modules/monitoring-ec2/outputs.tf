output "EC2-public-ip" {
  value = aws_eip.monitoring.public_ip
}