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

variable "orders_load_balancer_name" {
  description = "The name of the load balancer for the Orders Microservice"
  type        = string
  default     = "orders-load-balancer"
}

variable "target_group_port" {
  description = "The port of the target group"
  type        = number
  default     = 80
}
