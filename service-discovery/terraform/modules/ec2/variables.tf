variable "name_prefix" {
  type = string
}

variable "instance_count" {
  type = number
  default = 1
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
  default = "t3.micro"
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}