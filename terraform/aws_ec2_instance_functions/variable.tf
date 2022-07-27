variable "vpc_cidr_block" {
   type = string
   default = "10.0.0.0/16"
}

variable "pub_cidr_block" {
   type = list(string)
   default = ["10.0.0.0/18","10.0.64.0/18"]
}

variable "az" {
   type = list(string)
   default = ["us-east-1a","us-east-1b"]
}

variable "priv_cidr_block" {
   type = list(string)
   default = [ "10.0.128.0/18","10.0.192.0/18"]
}

variable "nat_gateway_count" {
   type = number
   default = 1
}

variable "instance_type" {
   type = string
   default = "t2.micro"
}
