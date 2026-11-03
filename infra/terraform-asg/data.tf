# ===== 기존 리소스 조회 =====
# infra/terraform에서 생성한 리소스를 이름(Name 태그)으로 조회만 하고 수정하지 않음

data "aws_vpc" "main" {
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# AZ 2d Private Subnet (10.0.103.0/24)
data "aws_subnet" "private_d" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-subnet-d"
  }
}

# 기존 Worker 보안그룹 (Kubelet / Calico / NodePort 규칙 재사용)
data "aws_security_group" "worker" {
  vpc_id = data.aws_vpc.main.id
  name   = "${var.project_name}-worker-sg"
}
