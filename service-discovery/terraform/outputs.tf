output "vpc_id" {
  description = "ID of the vpc"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of public subnet"
  value       = module.vpc.public_subnet_id
}

# ----- Consul Server ----- #
output "consul_server_private_ip" {
  description = "private IP address of consul server"
  value       = module.consul_server.private_ips[0]
}

output "consul_server_public_ip" {
  description = "public IP address of consul server"
  value       = module.consul_server.public_ips[0]
}

# ---- Backend Servers ---- #
output "backend_private_ips" {
  description = "private IP address of backend servers"
  value       = module.backends.private_ips
}

output "backend_public_ips" {
  description = "public IP address of backend servers"
  value       = module.backends.public_ips
}

# ----- Load Balancer -----#
output "lb_private_ip" {
  description = "private IP address of LB server"
  value       = module.load_balancer.private_ips[0]
}

output "lb_public_ip" {
  description = "public IP address of LB server"
  value       = module.load_balancer.public_ips[0]
}
