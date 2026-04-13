# CKS 실습 환경 설정

> Skilleat Labs — CKS 강의 실습 환경
> Ubuntu 24.04 ARM64 + VirtualBox + Kubernetes v1.32 + Calico

---

## 환경 구성

```
호스트 (M칩 맥북)
└── VirtualBox 7.2
    ├── controlplane  192.168.56.10  (CPU 2 / RAM 4GB)
    └── worker01      192.168.56.11  (CPU 2 / RAM 2GB)
```

---

## 설치 순서

### 1단계 — 모든 노드 공통 설정

controlplane과 worker01 **둘 다** 실행:

```bash
curl -fsSL https://raw.githubusercontent.com/skilleat-labs/cks-labs/main/setup-node.sh \
  | sudo bash
```

설치 항목:
- Swap 비활성화
- br_netfilter / overlay 커널 모듈
- containerd (SystemdCgroup=true)
- kubeadm / kubelet / kubectl v1.32
- kubelet node-ip 고정 (192.168.56.x 자동 감지)
- /etc/hosts 설정

---

### 2단계 — controlplane 초기화

controlplane **에서만** 실행:

```bash
curl -fsSL https://raw.githubusercontent.com/skilleat-labs/cks-labs/main/setup-controlplane.sh \
  | sudo bash
```

설치 항목:
- kubeadm init (pod-cidr: 172.16.0.0/16)
- kubectl 설정
- Calico CNI v3.29 설치
- worker join 명령어 출력

---

### 3단계 — worker01 클러스터 참여

2단계 완료 후 출력된 명령어를 worker01에서 실행:

```bash
sudo kubeadm join 192.168.56.10:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

---

### 4단계 — 확인

controlplane에서:

```bash
kubectl get nodes -o wide
# 두 노드 모두 Ready 상태면 완료
```

---

## 스냅샷 (Clone) 권장 시점

| 시점 | Clone 이름 |
|---|---|
| 클러스터 완성 직후 | controlplane-clean / worker01-clean |
| Ch 7 실습 전 | controlplane-ch07 |
| Ch 8 실습 전 | controlplane-ch08 |

VirtualBox에서 VM 우클릭 → Clone → Full Clone
