# ===== EC2 Compute =====

# ===== Master EC2 생성 (3대: a, c, d 가용영역) =====
resource "aws_instance" "master" {
  count = 3

  ami           = var.ubuntu_ami_id
  instance_type = var.master_instance_type

  # Master A, Master C, Master D
  subnet_id = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id,
    aws_subnet.private_d.id
  ][count.index]

  # key_name = aws_key_pair.main.key_name

  vpc_security_group_ids      = [aws_security_group.master.id]
  associate_public_ip_address = false # private 서브넷이므로 공인 IP 할당 X

  iam_instance_profile = aws_iam_instance_profile.ec2.name # IAM Role 연결

  depends_on = [aws_iam_role_policy_attachment.ssm] # SSM 정책 연결 후 EC2 설정 적용

  # 루트 EBS 30GiB (gp3)
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  lifecycle {
    prevent_destroy = false
  }
  disable_api_termination = false

  tags = {
    Name = "accordion-master-${["a", "c", "d"][count.index]}"
  }
}

# ===== Worker EC2 생성 (2대 기본, 필요 시 count 조정) =====
resource "aws_instance" "worker" {
  count = 2

  ami           = var.ubuntu_ami_id
  instance_type = var.worker_instance_type

  # Worker 서브넷 순환 배치 (a, c, d)
  subnet_id = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id,
    aws_subnet.private_d.id
  ][count.index % 3]

  # key_name = aws_key_pair.main.key_name

  vpc_security_group_ids      = [aws_security_group.worker.id]
  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  depends_on = [aws_iam_role_policy_attachment.ssm]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  lifecycle {
    prevent_destroy = false
  }
  disable_api_termination = false

  tags = {
    Name = "accordion-worker-${count.index + 1}-${["a", "c", "d"][count.index % 3]}"
  }
}