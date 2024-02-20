terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.37.0"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.2.0"
    }
  }
}

# Rancher2 administration provider
provider "rancher2" {
  alias = "admin"
  api_url = var.rancher_url

  token_key = var.rancher_token
  timeout   = "300s"
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}
