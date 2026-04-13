#!/bin/bash
# ============================================================
#  CKS 실습 환경 설정 스크립트 — 모든 노드 공통
#  Skilleat Labs | github.com/skilleat-labs/cks-labs
#
#  대상:  Ubuntu 24.04 ARM64 (VirtualBox on M-chip Mac)
#  설치:  containerd / kubeadm / kubelet / kubectl v1.32
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=============================================="
echo "  CKS 실습 환경 설정 시작"
echo "  Kubernetes v1.32 + containerd + Calico"
echo "=============================================="
echo ""

# ─────────────────────────────────────────────
# 0. root 권한 확인
# ─────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  fail "sudo 권한이 필요합니다. 'sudo bash setup-node.sh' 로 실행하세요."
fi

# ─────────────────────────────────────────────
# 1. Swap 비활성화
# ─────────────────────────────────────────────
info "Swap 비활성화 중..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
log "Swap 비활성화 완료"

# ─────────────────────────────────────────────
# 2. 네트워크 브리지 설정
# ─────────────────────────────────────────────
info "커널 모듈 로드 중..."
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system > /dev/null 2>&1
log "네트워크 브리지 설정 완료"

# ─────────────────────────────────────────────
# 3. containerd 설치
# ─────────────────────────────────────────────
info "containerd 설치 중..."
apt-get update -qq
apt-get install -y -qq containerd

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# SystemdCgroup 활성화
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd > /dev/null 2>&1
log "containerd 설치 완료 (SystemdCgroup=true)"

# ─────────────────────────────────────────────
# 4. kubeadm / kubelet / kubectl 설치 (v1.32)
# ─────────────────────────────────────────────
info "Kubernetes v1.32 설치 중..."
apt-get install -y -qq apt-transport-https ca-certificates curl gpg

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /
EOF

apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl > /dev/null 2>&1
log "kubeadm / kubelet / kubectl v1.32 설치 완료"

# ─────────────────────────────────────────────
# 5. kubelet Node IP 고정
# ─────────────────────────────────────────────
info "호스트 전용 어댑터 IP 확인 중..."

# 192.168.56.x 대역 IP 자동 감지
NODE_IP=$(ip addr | grep '192\.168\.56\.' | awk '{print $2}' | cut -d/ -f1 | head -1)

if [ -z "$NODE_IP" ]; then
  warn "192.168.56.x IP를 찾지 못했습니다."
  warn "호스트 전용 어댑터 IP를 수동으로 설정해주세요:"
  warn "  echo 'KUBELET_EXTRA_ARGS=--node-ip=<IP>' > /etc/default/kubelet"
else
  echo "KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}" > /etc/default/kubelet
  systemctl daemon-reload
  systemctl restart kubelet
  log "kubelet node-ip 고정 완료: ${NODE_IP}"
fi

# ─────────────────────────────────────────────
# 6. /etc/hosts 설정
# ─────────────────────────────────────────────
info "/etc/hosts 설정 중..."

# 기존 항목 중복 방지
grep -q "controlplane" /etc/hosts || cat <<EOF >> /etc/hosts

# Kubernetes 클러스터 노드
192.168.56.10  controlplane
192.168.56.11  worker01
EOF

# localhost 항목 확인 (Calico Felix 필수)
grep -q "127.0.0.1 localhost" /etc/hosts || echo "127.0.0.1 localhost" >> /etc/hosts

log "/etc/hosts 설정 완료"

# ─────────────────────────────────────────────
# 완료
# ─────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  설정 완료!"
echo "=============================================="
echo ""
echo "  다음 단계:"
echo ""
echo "  [controlplane 전용]"
echo "  sudo kubeadm init \\"
echo "    --pod-network-cidr=172.16.0.0/16 \\"
echo "    --apiserver-advertise-address=192.168.56.10"
echo ""
echo "  [worker01 전용]"
echo "  sudo kubeadm join 192.168.56.10:6443 \\"
echo "    --token <TOKEN> \\"
echo "    --discovery-token-ca-cert-hash sha256:<HASH>"
echo ""
