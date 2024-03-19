variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type = map(string)
  default = {
    managed_by_terraform = true
  }
}

variable "load_balancer_name" {
  description = "The name of the load balancer"
  type        = string
  default     = "self-order-management-lb"
}

variable "target_group_port" {
  description = "The port of the target group"
  type        = number
  default     = 80
}
