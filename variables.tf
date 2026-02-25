variable "rg_name" {
  description = "Resource group name"
  type        = string
}

variable "sa_name" {
  description = "Storage account name"
  type        = string
}

variable "sub_id" {
  type = string
}

variable "app_service_plan_name" {
  type = string
}

variable "function_app_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "nsg_name" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "add_space" {
  type = list(string)
}

variable "subnet_name" {
  type = string
}

variable "sub_prefix" {
  type = list(string)
}

variable "linux_vm_password" {
  type = string
}

