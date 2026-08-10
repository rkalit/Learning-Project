terraform {
  backend "s3" {
    bucket       = "experimental-statefull"
    key          = "consul-lab/terraform.tfstate"
    region       = "ap-southeast-3"
    profile      = "terraform-lab"
    encrypt      = true
    use_lockfile = true
  }
}
