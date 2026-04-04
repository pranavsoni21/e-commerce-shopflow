terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-shopflow"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "shopflow-lock-table"
  }
}