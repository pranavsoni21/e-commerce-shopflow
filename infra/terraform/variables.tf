variable "project_name" {
  type    = string
  default = "shopflow"
}

variable "environment" {
  type    = string
  default = "Testing"
}

variable "github_org" {
  type = string
  default = "pranavsoni21"
}

variable "github_repo" {
  type = string
  default = "e-commerce-shopflow"
}

variable "db_username" {
  type      = string
  sensitive = true
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default = "password"
}