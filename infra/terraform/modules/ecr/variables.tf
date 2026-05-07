variable "tags" {
  type = map(string)
}

variable "repositories_to_create" {
  type = map(string)
  default = {
    "1" : "user",
    "2" : "product",
    "3" : "order",
    "4" : "notification"
  }
}