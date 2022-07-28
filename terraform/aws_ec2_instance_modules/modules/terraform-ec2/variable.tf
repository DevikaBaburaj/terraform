variable "key_name" {
   type = string
}

variable "public_key" {
   type = string
}

variable "instance_type" {
   type = string
}

variable "user_data" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "device_name" {
  type = string
}

variable "volume_size" {
  type = number
}

variable "volume_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "alb_name" {
  type = string
}

variable "internal" {
  type = bool
}

variable "load_balancer_type" {
  type = string
}

variable "alb_subnets" {
  type = list(string)
}

variable "tg_name" {
  type = string
}

variable "tg_port" {
  type = number
}

variable "tg_protocol" {
   type = string
}

variable "deregistration_delay" {
    type = number
}

variable "target_type" {
  type = string
}

variable "healthy_threshold" {
  type = number
}

variable "interval" {
  type = number
}

variable "matcher" {
   type = number
}

variable "timeout" {
  type = number
}

variable "path" {
  type = string
}

variable "unhealthy_threshold" {
  type = number
}