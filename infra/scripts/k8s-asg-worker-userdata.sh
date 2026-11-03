#!/usr/bin/env bash

# ============================================================
# KT Cloud Chicken Team - ASG Worker 자동 Join (user_data)
# ============================================================
# 목적: Auto Scaling Group으로 생성된 Worker EC2를 클러스터에 자동 Join
# 대상: ASG Worker EC2 (Launch Template user_data로 실행)
#
# 진행 순서:
#   1. Swap 비활성화 / 커널 모듈 / 네트워크 설정   (k8s-init.sh 동일)
#   2. containerd 설치 및 systemd cgroup 설정       (k8s-init.sh 동일)
#   3. kubelet / kubeadm 설치 및 버전 고정           (k8s-install.sh 동일)
#   4. SSM Parameter Store에서 Join 명령 조회 후 Join
#   5. serverTLSBootstrap 활성화                     (k8s-kubelet-tls.sh 동일)
#
# 사전 조건:
# - Master에서 Join 명령을 SSM Parameter Store에 저장
#     JOIN_CMD=$(sudo kubeadm token create --ttl 0 --print-join-command)
#     aws ssm put-parameter --name ${join_param} \
#       --type SecureString --value "$JOIN_CMD" --overwrite --region ${region}
#
# 로그 확인: sudo tail -100 /var/log/cloud-init-output.log
#
# 주의:
# - Terraform templatefile로 렌더링되는 파일입니다.
# - bash 변수는 중괄호 없이 $VAR 형태로 사용합니다.
# - Join 후 kubelet serving CSR은 Master에서 승인해야 합니다.
#     kubectl get csr
#     kubectl certificate approve <CSR_NAME>
# ============================================================

set -euxo pipefail

REGION="${region}"
JOIN_PARAM="${join_param}"
K8S_VERSION="${k8s_version}"
K8S_REPO_VERSION="${k8s_repo_version}"
NODE_LABELS="${node_labels}"

# 1. Swap 비활성화
echo "[1/5] Swap / Kernel / Network"

swapoff -a
sed -i '/^[[:space:]]*[^#[:space:]].*[[:space:]]swap[[:space:]]/s/^[[:space:]]*/# /' /etc/fstab

cat > /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# 2. containerd 설치 및 설정
echo "[2/5] containerd"

apt-get update
apt-get install -y containerd apt-transport-https ca-certificates curl gpg

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

sed -i -E \
  's/^([[:space:]]*SystemdCgroup[[:space:]]*=[[:space:]]*).*/\1true/' \
  /etc/containerd/config.toml

systemctl enable --now containerd
systemctl restart containerd

# 3. Kubernetes 패키지 설치 (기존 노드와 동일 버전)
echo "[3/5] kubelet / kubeadm"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/$K8S_REPO_VERSION/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_REPO_VERSION/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y \
  "kubelet=$K8S_VERSION-1.1" \
  "kubeadm=$K8S_VERSION-1.1"

apt-mark hold kubelet kubeadm

# ASG 노드 구분용 라벨 (Pod 배치 / 모니터링 필터에 사용)
echo "KUBELET_EXTRA_ARGS=--node-labels=$NODE_LABELS" > /etc/default/kubelet
systemctl enable kubelet

# 4. Join 명령 조회 후 Join
echo "[4/5] kubeadm join"

snap install aws-cli --classic

JOIN_CMD=$(/snap/bin/aws ssm get-parameter \
  --name "$JOIN_PARAM" \
  --with-decryption \
  --query Parameter.Value \
  --output text \
  --region "$REGION")

eval "$JOIN_CMD --cri-socket unix:///run/containerd/containerd.sock"

# 5. serverTLSBootstrap 활성화 (Metrics Server x509 오류 방지)
echo "[5/5] serverTLSBootstrap"

CONFIG="/var/lib/kubelet/config.yaml"

if grep -Eq '^[[:space:]]*serverTLSBootstrap:' "$CONFIG"; then
    sed -i -E 's/^([[:space:]]*serverTLSBootstrap:).*/\1 true/' "$CONFIG"
else
    printf '\nserverTLSBootstrap: true\n' >> "$CONFIG"
fi

systemctl restart kubelet

echo "===== ASG Worker Join 완료 ====="
