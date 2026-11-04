# ===== Worker Auto Scaling (AZ 2d) =====
# CloudWatch CPU 알람 기반 Step Scaling
# - Scale Out: 평균 CPU >= asg_scale_out_cpu (1분) → +1
# - Scale In : 평균 CPU <  asg_scale_in_cpu (5분)  → -1
#
# Join 명령 조회(ssm:GetParameter)는 기존 Role의
# AmazonSSMManagedInstanceCore 정책에 포함되어 있어 IAM을 추가하지 않음

locals {
  asg_name         = "${var.project_name}-asg-worker"
  join_param_name  = "/${var.project_name}/k8s/join-command"
  k8s_repo_version = "v${join(".", slice(split(".", var.k8s_version), 0, 2))}" # 1.36.5 → v1.36
}

# ===== Launch Template (기존 Worker와 동일 AMI / 사양 / 보안그룹) =====
resource "aws_launch_template" "worker" {
  name_prefix   = "${local.asg_name}-"
  image_id      = var.ubuntu_ami_id
  instance_type = var.worker_instance_type

  vpc_security_group_ids = [data.aws_security_group.worker.id]

  iam_instance_profile {
    name = "${var.project_name}-ec2-ssm-profile" # 기존 Instance Profile 재사용 (SSM / ECR 권한)
  }

  # 루트 EBS 30GiB (gp3)
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  # 1분 단위 CloudWatch 지표 (기본 5분이면 알람 반응이 느림)
  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/../scripts/k8s-asg-worker-userdata.sh", {
    region           = var.aws_region
    join_param       = local.join_param_name
    k8s_version      = var.k8s_version
    k8s_repo_version = local.k8s_repo_version
    node_labels      = "${var.project_name}/node-group=asg"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = local.asg_name
    }
  }
}

# ===== Auto Scaling Group =====
resource "aws_autoscaling_group" "worker" {
  name                = local.asg_name
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_min_size
  vpc_zone_identifier = [data.aws_subnet.private_d.id] # AZ 2d (10.0.103.0/24)

  # 노드 Join + kubelet 기동까지 대기 (이 시간 동안 새 노드 CPU는 평균에서 제외)
  default_instance_warmup = 300
  health_check_type       = "EC2"

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]

  # 스케일링 정책이 바꾼 desired 값을 terraform apply가 되돌리지 않도록
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ===== Scale Out 정책 =====
resource "aws_autoscaling_policy" "scale_out" {
  name                      = "${local.asg_name}-scale-out"
  autoscaling_group_name    = aws_autoscaling_group.worker.name
  policy_type               = "StepScaling"
  adjustment_type           = "ChangeInCapacity"
  estimated_instance_warmup = 300

  # 임계값 이상 : +1대
  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment          = 1
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.asg_name}-cpu-high"
  alarm_description   = "ASG Worker 평균 CPU ${var.asg_scale_out_cpu}% 이상 (1분) → Scale Out"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60 # EC2 상세 모니터링 최소 단위 (1분)
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.asg_scale_out_cpu

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

# ===== Scale In 정책 =====
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${local.asg_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"

  step_adjustment {
    metric_interval_upper_bound = 0
    scaling_adjustment          = -1
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.asg_name}-cpu-low"
  alarm_description   = "ASG Worker 평균 CPU ${var.asg_scale_in_cpu}% 미만 (5분) → Scale In"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  comparison_operator = "LessThanThreshold"
  threshold           = var.asg_scale_in_cpu

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}

# ===== ALB 대상 그룹 연결 =====
# ASG가 띄운 Worker를 chicken-web-tg(NodePort 30080)에 자동 등록 / 축소 시 자동 해제
resource "aws_autoscaling_attachment" "web" {
  autoscaling_group_name = aws_autoscaling_group.worker.name
  lb_target_group_arn    = data.aws_lb_target_group.web.arn
}
