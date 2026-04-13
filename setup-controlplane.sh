#!/bin/bash
# ============================================================
#  CKS 실습 환경 — controlplane 초기화 스크립트
#  setup-node.sh 실행 완료 후, controlplane 에서만 실행
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=============================================="
echo "  controlplane 초기화 시작"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
  fail "sudo 권한이 필요합니다."
fi

# ─────────────────────────────────────────────
# 1. kubeadm init
# ─────────────────────────────────────────────
info "kubeadm init 실행 중... (2~3분 소요)"

kubeadm init \
  --pod-network-cidr=172.16.0.0/16 \
  --apiserver-advertise-address=192.168.56.10 \
  | tee /tmp/kubeadm-init.log

log "kubeadm init 완료"

# ─────────────────────────────────────────────
# 2. kubectl 설정 (ubuntu 사용자)
# ─────────────────────────────────────────────
info "kubectl 설정 중..."

REAL_USER=${SUDO_USER:-ubuntu}
REAL_HOME=$(eval echo ~$REAL_USER)

mkdir -p $REAL_HOME/.kube
cp -i /etc/kubernetes/admin.conf $REAL_HOME/.kube/config
chown $(id -u $REAL_USER):$(id -g $REAL_USER) $REAL_HOME/.kube/config

log "kubectl 설정 완료 (사용자: $REAL_USER)"

# ─────────────────────────────────────────────
# 3. Calico CNI 설치
# ─────────────────────────────────────────────
info "Calico CNI 설치 중..."

# ubuntu 사용자 권한으로 kubectl 실행
sudo -u $REAL_USER kubectl apply \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/calico.yaml

log "Calico CNI 설치 완료"

# ─────────────────────────────────────────────
# 4. join 명령어 출력
# ─────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  초기화 완료!"
echo "=============================================="
echo ""
echo "  worker01 에서 아래 명령어를 실행하세요:"
echo ""

# kubeadm init 로그에서 join 명령 추출
grep -A 2 "kubeadm join" /tmp/kubeadm-init.log | tail -3
echo ""
echo "  노드 상태 확인 (2~3분 후):"
echo "  kubectl get nodes -o wide"
echo ""
