# ===== 보안그룹 관련 tf =====

# 로컬 변수 정의: 모든 Private 서브넷(A, C, D) CIDR 묶음
locals {
  k8s_cluster_subnets = [
    var.private_sub_a_cidr,
    var.private_sub_c_cidr,
    var.private_sub_d_cidr
  ]
}

# ===== Master Security Group =====
resource "aws_security_group" "master" {
  name        = "accordion-master-sg"
  description = "Security group for Master EC2 (HA Control Plane)"
  vpc_id      = aws_vpc.main.id

<<<<<<< HEAD
  # 1. Kubernetes API Server (Worker -> Master, Master <-> Master)
=======

 # worker EC2에서 Master EC2로 접근 허용 : k8s API server

>>>>>>> ebd6b76a4cee21b4849c4c4902cab40365d588f8
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
<<<<<<< HEAD
    cidr_blocks = local.k8s_cluster_subnets
=======
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
>>>>>>> ebd6b76a4cee21b4849c4c4902cab40365d588f8
  }

  # 2. etcd 서버 클라이언트 및 피어 간 통신 (Master <-> Master HA 필수)
  ingress {
    description = "etcd server client and peer communication"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 3. Kubelet API (Master -> Master / Control Plane 컴포넌트 헬스체크)
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 4. kube-controller-manager 및 kube-scheduler 로컬/내부 헬스체크
  ingress {
    description = "kube-controller-manager and kube-scheduler"
    from_port   = 10257
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 5. Calico VXLAN (Pod 간 오버레이 네트워크 통신)
  ingress {
    description = "Calico VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
<<<<<<< HEAD
    cidr_blocks = local.k8s_cluster_subnets
=======
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ] #[aws_security_group.worker.id]
>>>>>>> ebd6b76a4cee21b4849c4c4902cab40365d588f8
  }

  # 6. Calico Typha
  ingress {
    description = "Calico Typha"
    from_port   = 5473
    to_port     = 5473
    protocol    = "tcp"
<<<<<<< HEAD
    cidr_blocks = local.k8s_cluster_subnets
=======
    cidr_blocks = [
      var.private_sub_a_cidr,
      var.private_sub_c_cidr,
    ] # Worker Subnet D CIDR
>>>>>>> ebd6b76a4cee21b4849c4c4902cab40365d588f8
  }

  # 7. Calico BGP (BGP 모드 사용 시)
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
<<<<<<< HEAD
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 전체 아웃바운드 허용
=======
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
>>>>>>> ebd6b76a4cee21b4849c4c4902cab40365d588f8
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


# ===== Worker Security Group =====
resource "aws_security_group" "worker" {
  name        = "accordion-worker-sg"
  description = "Security group for Worker EC2"
  vpc_id      = aws_vpc.main.id

  # 1. Kubelet API (Master -> Worker Pod 로그 수집, exec 등)
  ingress {
    description = "Kubelet API from Cluster"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 2. Calico VXLAN (Worker <-> Worker, Worker <-> Master Pod 통신)
  ingress {
    description = "Calico VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 3. Calico BGP
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 4. Chicken App NodePort (인스턴스 참조 대신 서브넷 대역으로 지정하여 순환 참조 제거)
  ingress {
    description = "Chicken App NodePort"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # (선택) 표준 K8s NodePort 전체 대역(30000-32767) 허용 필요 시 추가
  ingress {
    description = "Kubernetes NodePort Services default range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = local.k8s_cluster_subnets
  }

  # 전체 아웃바운드 허용
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