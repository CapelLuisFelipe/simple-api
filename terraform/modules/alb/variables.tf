variable "name_prefix" {
  type    = string
  default = "simple-api"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "target_port" {
  type    = number
  default = 3000
}

variable "tags" {
  type    = map(string)
  default = {}
}
