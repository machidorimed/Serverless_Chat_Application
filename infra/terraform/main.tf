terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

}

# backend
terraform {
  backend "s3" {
    bucket = "aws-study-marube23-backet"
    key    = "chat-app/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Application = "Chat-app"
    }
  }
}

# アカウントIDを動的に取得。
# アカウントIDを書かずセキュアに保存できるが、
# 意図しないアカウントにリソースが作られるリスクあり。
data "aws_caller_identity" "current" {}
