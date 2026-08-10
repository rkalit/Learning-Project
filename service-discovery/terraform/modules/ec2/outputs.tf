output "private_ips" {
  value = aws_instance.this[*].private_ip
}

output "public_ips" {
  value = aws_instance.this[*].public_ip
}

output "instance_ids" {
  value = aws_instance.this[*].id
}