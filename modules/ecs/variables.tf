variable "layer" {
  type        = string
}

variable "stack_id" {
  type        = string
}

variable "app_image" {
  description = "Docker image to run in the ECS cluster"
  type        = string
  default = "nginx"
}

variable "app_port" {
  type        = number
  default = 80
}

variable "app_count" {
  type        = number
  default = 1
}

variable "fargate_cpu" {
  type        = string
  default = "512"
}

variable "fargate_memory" {
  type        = string
  default = "1024"
}

variable "region" {
  type        = string
}

variable "db_subnets_public" {
  type        = list(string)
}

variable "db_subnets_private" {
  type        = list(string)
}

variable "vpc" {
  type        = string
}

variable "account_id" {
  description = "aws account id"
  type        = string
}

variable "parameters_secrets" {
  description = "secrets"
}
