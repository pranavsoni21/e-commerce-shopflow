variable "tags" {
  type = map(string)
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "private_sub_cidr" {
  type = map(string)
  default = {
    "private-subnet-1" = "10.0.4.0/24",
    "private-subnet-2" = "10.0.5.0/24",
    "private-subnet-3" = "10.0.6.0/24"
  }
}

variable "public_sub_cidr" {
  type = map(string)
  default = {
    "public-subnet-1" = "10.0.1.0/24",
    "public-subnet-2" = "10.0.2.0/24",
    "public-subnet-3" = "10.0.3.0/24"
  }
}