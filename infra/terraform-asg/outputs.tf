# ===== Auto Scaling 정보 =====
output "asg_worker_name" {
  description = "Worker Auto Scaling Group Name"
  value       = aws_autoscaling_group.worker.name
}

output "launch_template_id" {
  description = "Worker Launch Template ID"
  value       = aws_launch_template.worker.id
}

output "join_param_name" {
  description = "kubeadm join 명령을 저장할 SSM Parameter 이름"
  value       = local.join_param_name
}

# 조회된 기존 리소스 확인용
output "private_subnet_d_id" {
  description = "ASG가 사용하는 Private Subnet D ID"
  value       = data.aws_subnet.private_d.id
}

output "worker_security_group_id" {
  description = "ASG가 사용하는 Worker Security Group ID"
  value       = data.aws_security_group.worker.id
}
