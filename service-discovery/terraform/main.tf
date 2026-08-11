# ------ VPC ------ #
module "vpc" {
  source = "./modules/vpc"

  vpc_name           = "consul-lab-vpc"
  vpc_cidr           = "172.16.0.0/16"
  public_subnet_cidr = "172.16.0.0/24"
  availability_zone  = "ap-southeast-3a"
}

# ------ SG ------ #
resource "aws_security_group" "lab_sg" {
  name        = "consul-lab-sg"
  description = "Allow SSH and Consul/Nginx traffic for the lab"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from local"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP for Nginx/LB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Consul internal traffic (server + agents)"
    from_port   = 8300
    to_port     = 8600
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Consul serf LAN gossip (UDP)"
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "consul-lab-sg" }
}

# ------ Key ------ #
resource "aws_key_pair" "lab_key" {
  key_name   = "consul-lab-key"
  public_key = file("~/.ssh/id_ed25519_con.pub")
}

# ------ EC2 ------ #
# ---- Consul ----- #
module "consul_server" {
  source = "./modules/ec2"

  name_prefix        = "consul-server"
  instance_count     = 1
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.public_subnet_id
  security_group_ids = [aws_security_group.lab_sg.id]
  key_name           = aws_key_pair.lab_key.key_name
}
# ---- Backend ---- #
module "backends" {
  source = "./modules/ec2"

  name_prefix        = "backend-server"
  instance_count     = 2
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.public_subnet_id
  security_group_ids = [aws_security_group.lab_sg.id]
  key_name           = aws_key_pair.lab_key.key_name
}
# ----- LB ----- #
module "load_balancer" {
  source = "./modules/ec2"

  name_prefix        = "load-balancer"
  instance_count     = 1
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.public_subnet_id
  security_group_ids = [aws_security_group.lab_sg.id]
  key_name           = aws_key_pair.lab_key.key_name
}
