provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

module "vpc" {
  source               = "./modules/terraform-vpc"
  vpc_cidr_block       = "10.0.0.0/16"
  pub_cidr_block       = ["10.0.0.0/18", "10.0.64.0/18"]
  priv_cidr_block      = ["10.0.128.0/18", "10.0.192.0/18"]
  az                   = ["us-east-1a", "us-east-1b"]
  nat_gateway_count    = 1
  enable_dns_hostnames = true
  enable_dns_support   = true

}

module "ec2" {
  source               = "./modules/terraform-ec2"
  key_name             = "deployer-name"
  public_key           = file("~/.ssh/id_rsa.pub")
  instance_type        = "t2.micro"
  user_data            = file("${path.module}/install_apache.sh")
  subnet_id            = module.vpc.priv_subnet
  device_name          = "/dev/sdf"
  volume_size          = 30
  volume_type          = "gp2"
  vpc_id               = module.vpc.vpc_id
  alb_name             = "web-alb"
  internal             = false
  load_balancer_type   = "application"
  alb_subnets          = module.vpc.subnets
  tg_name              = "tf-lb-tg"
  tg_port              = 80
  tg_protocol          = "HTTP"
  deregistration_delay = 30
  target_type          = "instance"
  healthy_threshold    = 3
  interval             = 40
  matcher              = 200
  timeout              = 30
  path                 = "/"
  unhealthy_threshold  = 2

}
