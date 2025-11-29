# Terraform Backend Configuration

terraform {
  backend "s3" {
    bucket         = "johuaazi-terraform-state-1764347347"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
  }
}
