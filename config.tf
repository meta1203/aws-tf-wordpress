variable "r53_domain" {
  description = "The Route 53 domain name"
  type = string
}

variable "region" {
  description = "Region to host in"
  type = string
  default = "us-east-1"
}

variable "r53_subdomain" {
  description = "Subdomains to bind to"
  type = list(string)
  default = ["", "www."]
}

variable "ecs_cpu" {
  description = "Number of CPU units per ECS task (1 core = 1024)"
  type = number
  default = 256
  validation {
    condition = var.ecs_cpu > 128
    error_message = "ECS CPU units must be > 128."
  }
}

variable "ecs_mem" {
  description = "MB of RAM per ECS task"
  type = number
  default = 1024
  validation {
    condition = var.ecs_mem > 512
    error_message = "ECS memory must be > 512M."
  }
}

variable "max_capacity" {
  description = "Max number of ECS instances that can be running at once"
  type = number
  default = 4
}
