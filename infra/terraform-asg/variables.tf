# ===== 기본 설정 =====
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "기존 리소스 조회에 사용하는 프로젝트 이름 (Name 태그 prefix)"
  type        = string
  default     = "accordion"
}

# ===== Worker EC2 설정 (기존 Worker와 동일하게 유지) =====
variable "ubuntu_ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-0e1eeb87102d64f40"
}

variable "worker_instance_type" {
  description = "Kubernetes Worker instance type"
  type        = string
  default     = "t3.medium"
}

variable "k8s_version" {
  description = "kubelet / kubeadm 버전 (기존 노드와 동일)"
  type        = string
  default     = "1.36.5"
}

# ===== Auto Scaling 설정 =====
variable "asg_min_size" {
  description = "ASG Worker 최소 대수 (0이면 CPU 지표가 없어 자동 Scale Out 불가 → desired 수동 변경)"
  type        = number
  default     = 0
}

variable "asg_max_size" {
  description = "ASG Worker 최대 대수"
  type        = number
  default     = 1
}

variable "asg_scale_out_cpu" {
  description = "Scale Out 기준 ASG 평균 CPU 사용률(%)"
  type        = number
  default     = 60
}

variable "asg_scale_in_cpu" {
  description = "Scale In 기준 ASG 평균 CPU 사용률(%)"
  type        = number
  default     = 30
}

# ===== ALB 연결 =====
variable "alb_target_group_name" {
  description = "ASG Worker를 자동 등록할 ALB 대상 그룹 이름"
  type        = string
  default     = "chicken-web-tg"
}
