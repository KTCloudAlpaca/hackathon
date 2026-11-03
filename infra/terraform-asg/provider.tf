# ===== provider 설정 =====
# 기존 infra/terraform과 state를 분리한 Worker Auto Scaling 전용 모듈
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"

      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
