variable "vpc_cidr_block" {
   type = string
}

variable "pub_cidr_block" {
   type = list(string)
}

variable "az" {
   type = list(string)
}

variable "priv_cidr_block" {
   type = list(string)
}

variable "nat_gateway_count" {
   type = number
}

variable "enable_dns_hostnames" {
   type = bool
}

variable "enable_dns_support" {
   type = bool
}
