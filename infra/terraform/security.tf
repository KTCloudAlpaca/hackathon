# ===== 보안그룹 관련 tf =====

# ===== Master Security Group  =====
# Master EC2에 적용
resource "aws_security_group" "master" {
  name        = "accordion-master-sg"
  description = "Security group for Master EC2"
  vpc_id      = aws_vpc.main.id


 # worker EC2에서 Master EC2로 접근 허용 : k8s API server

  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ] #[aws_security_group.worker.id]
  }

  # Master <-> Master: stacked etcd
  ingress {
    description = "etcd between control plane nodes"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ]
  }

  # worker EC2에서 Master EC2로 접근 허용 : Calico VXLAN
  ingress {
    description = "Calico VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ] #[aws_security_group.worker.id]
  }
  # worker EC2에서 Master EC2로 접근 허용 : Calico Typha
  ingress {
    description = "Calico Typha"
    from_port   = 5473
    to_port     = 5473
    protocol    = "tcp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ] # Worker Subnet D CIDR
  }

  # worker EC2에서 Master EC2로 접근 허용 : Calico BGP
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ] # Worker Subnet D CIDR
  }

  # worker EC2에서 Master EC2로 접근 허용 : kubelet API
  ingress {
    description = "kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ] #[aws_security_group.worker.id]
  }

  # Master EC2의 전체 아웃바운드 트래픽 허용
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "accordion-master-sg"
  }
}

##==============================
##==============================
##====인바운드 규칙 추가 필요====
##==============================
##==============================


# ===== Worker Security Group  =====
# Worker EC2에 적용

resource "aws_security_group" "worker" {
  name        = "accordion-worker-sg"
  description = "Security group for Worker EC2"
  vpc_id      = aws_vpc.main.id

  # Master EC2에서 Worker EC2로 접근 허용 : kubelet API
  ingress {
    description = "kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
      var.private_sub_d_cidr,
    ] #[aws_security_group.master.id]
  }

  # Master EC2에서 Worker EC2로 접근 허용 : Calico VXLAN
  ingress {
    description = "Calico VXLAN from Master"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
      var.private_sub_d_cidr,
    ] #[aws_security_group.master.id]
  }

  # Master EC2에서 Worker EC2로 접근 허용 : Calico BGP
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
      var.private_sub_d_cidr,
    ] # Master Subnet B CIDR
  }

  # 노도포트 개방
  ingress {
    description = "chicken app nodeport"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = [
      "${aws_instance.master[0].private_ip}/32",
      "${aws_instance.master[1].private_ip}/32"
    ]
  }

  # Worker EC2의 전체 아웃바운드 트래픽 허용
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "accordion-worker-sg"
  }
}
