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
}

variable "github_repo" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}