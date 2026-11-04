# ACCORDION -- Worker Auto Scaling (Terraform)
Kubernetes Worker 노드(EC2)를 AWS Auto Scaling Group으로 자동 확장·축소하기 위한 Terraform 코드입니다.

새로 생성된 노드는 사람의 개입 없이 **클러스터에 자동 Join**하고, **ALB 대상 그룹에 자동 등록**됩니다.

## 주요 구성
- **Auto Scaling Group**: AZ 2d Private Subnet(`10.0.103.0/24`)에 Worker EC2 생성
- **Launch Template**: 기존 Worker와 동일한 AMI / 사양 / 보안그룹 / Instance Profile
- **Scaling 정책**: CloudWatch CPU 알람 기반 Step Scaling
- **자동 Join**: user_data가 SSM Parameter Store에서 `kubeadm join` 명령을 조회해서 실행
- **ALB 연결**: `chicken-web-tg`(NodePort 30080)에 자동 등록 / 축소 시 자동 해제

| 항목 | 값 |
| --- | --- |
| 노드 사양 | t3.medium, Ubuntu 24.04, Kubernetes v1.36.5, containerd |
| 용량 (기본값) | 최소 1 / 최대 2 |
| Scale Out | ASG 평균 CPU **60% 이상 2분** 지속 → +1대 |
| Scale In | ASG 평균 CPU **30% 미만 5분** 지속 → -1대 |
| 노드 라벨 | `accordion/node-group=asg` |

## 동작 흐름
```
[CloudWatch 알람] ─CPU ≥ 60% / < 30%─▶ [Scaling 정책] ─▶ [Auto Scaling Group (2d)]
                                                                │
                                                     Launch Template + user_data
                                                                ▼
                                                        [Worker EC2 생성]
                                                                │
                              SSM Parameter Store에서 join 명령 조회 → kubeadm join
                                                                ▼
                                                [Kubernetes 클러스터에 자동 참여]
                                                                │
                                                ASG ↔ 대상 그룹 연결 (자동 등록/해제)
                                                                ▼
                                            [ALB chicken-web-tg → ㅈNodePort 30080]
```

## Terraform 파일 구조
```
terraform-asg/
├── provider.tf              # AWS Provider 및 Terraform 설정
├── data.tf                  # 기존 리소스 조회 (VPC, Subnet D, Worker SG, ALB 대상 그룹)
├── variables.tf             # 입력 변수 (모두 기본값 있음)
├── terraform.tfvars.example # 환경 설정 예시 파일
├── autoscaling.tf           # Launch Template, ASG, Scaling 정책, CloudWatch 알람, ALB 연결
├── outputs.tf               # ASG / 조회된 리소스 정보 출력
├── .terraform.lock.hcl      # Provider 버전 고정
└── README.md

../scripts/
└── k8s-asg-worker-userdata.sh   # 새 Worker 자동 Join 스크립트 (templatefile로 렌더링)
```

## 기존 인프라(`infra/terraform`)와 분리한 이유
기존 인프라의 state는 `.gitignore`로 제외되어 있어서 apply한 PC에만 있습니다. 같은 폴더에서 apply하면 VPC부터 전체를 새로 만들려고 하는 문제가 있습니다.

그래서 이 모듈은 **state를 분리**하고, 기존 리소스는 **Name 태그로 조회(data source)만** 합니다.
- 기존 인프라를 **수정하거나 삭제하지 않습니다**
- IAM을 새로 만들지 않습니다. join 명령 조회(`ssm:GetParameter`)는 기존 Role의 `AmazonSSMManagedInstanceCore`에 포함되어 있습니다
- `terraform destroy` 시 ASG 관련 리소스만 삭제됩니다

| 조회 대상 | 이름 |
| --- | --- |
| VPC | `accordion-vpc` |
| Subnet | `accordion-private-subnet-d` |
| Security Group | `accordion-worker-sg` |
| Instance Profile | `accordion-ec2-ssm-profile` |
| ALB 대상 그룹 | `chicken-web-tg` |

## ⚠️ State 위치
이 모듈의 state는 **Master D (`10.0.103.208`)** 에만 있습니다.
```
/home/ubuntu/hackathon/infra/terraform-asg/terraform.tfstate
```
`plan` / `apply` / `destroy`는 **반드시 Master D에서** 실행하세요. 다른 곳에서 apply하면 ASG가 중복 생성됩니다.

## 사전 준비

### 1. AWS 자격증명
Master D의 Instance Role에는 ASG / CloudWatch 생성 권한이 없으므로 클러스터 계정의 Access Key를 사용합니다.
```bash
export AWS_ACCESS_KEY_ID=<ACCESS_KEY>
export AWS_SECRET_ACCESS_KEY=<SECRET_KEY>
export AWS_DEFAULT_REGION=ap-northeast-2

aws sts get-caller-identity   # 클러스터 계정인지 확인
```
> `aws configure`로 디스크에 저장하지 말고 `export`로 세션에서만 사용하세요. 키를 채팅이나 GitHub에 붙여넣지 마세요.

### 2. kubeconfig (root로 접속한 경우)
```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

### 3. Join 명령을 SSM Parameter Store에 저장 (최초 1회)
```bash
JOIN_CMD=$(kubeadm token create --ttl 0 --print-join-command)
aws ssm put-parameter --name /accordion/k8s/join-command \
  --type SecureString --overwrite --value "$JOIN_CMD"
```
> 파라미터가 없으면 EC2는 생성되지만 클러스터에 Join하지 못합니다.

## 실행 방법
```bash
cd /home/ubuntu/hackathon/infra/terraform-asg
terraform init
terraform plan      # 기존 리소스 change / destroy가 없는지 확인
terraform apply
```
값을 바꾸려면 `-var`로 넘기거나 `terraform.tfvars`를 만들어 사용합니다.
```bash
# 예: 비용 절약용 (평소 0대, 자동 확장 없음)
terraform apply -var="asg_min_size=0" -var="asg_max_size=1"
```

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `asg_min_size` | `1` | 최소 대수 (CPU 자동 확장을 위해 1 이상) |
| `asg_max_size` | `2` | 최대 대수 |
| `asg_scale_out_cpu` | `60` | Scale Out 기준 CPU(%) |
| `asg_scale_in_cpu` | `30` | Scale In 기준 CPU(%) |
| `alb_target_group_name` | `chicken-web-tg` | 자동 등록할 ALB 대상 그룹 |
| `ubuntu_ami_id` / `worker_instance_type` / `k8s_version` | 기존 Worker와 동일 | 노드 환경 |

## 운영 명령어

### 노드 수동으로 늘리기 / 전부 내리기
```bash
# 최대 대수 안에서 수동으로 늘리기
aws autoscaling set-desired-capacity --auto-scaling-group-name accordion-asg-worker --desired-capacity 2

# 전부 내리기 (최소 1대라서 min도 같이 0으로 낮춰야 함)
aws autoscaling update-auto-scaling-group --auto-scaling-group-name accordion-asg-worker \
  --min-size 0 --desired-capacity 0
# 다시 원래대로 (terraform 기본값 min 1 복구)
terraform apply
```

### 새 노드 확인 (생성 후 3~5분)
```bash
kubectl get nodes -L accordion/node-group -o wide   # NODE-GROUP = asg, Ready

# kubelet-serving CSR 승인 (새 노드마다 필요, kubectl top / HPA용)
kubectl get csr --no-headers | awk '$3=="kubernetes.io/kubelet-serving" && $NF=="Pending"{print $1}' | xargs -r kubectl certificate approve
```

### ALB 대상 그룹 확인 (생성 후 8~10분이면 healthy)
```bash
TG_ARN=$(aws elbv2 describe-target-groups --names chicken-web-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
```

### 스케일링 기록 / 알람 상태
```bash
aws autoscaling describe-scaling-activities --auto-scaling-group-name accordion-asg-worker --max-items 5 \
  --query 'Activities[].{Time:StartTime,Status:StatusCode,What:Description}' --output table

aws cloudwatch describe-alarms --alarm-name-prefix accordion-asg-worker \
  --query 'MetricAlarms[].[AlarmName,StateValue,ActionsEnabled]' --output table
```

### 자동 축소 잠시 끄기 / 켜기
```bash
aws cloudwatch disable-alarm-actions --alarm-names accordion-asg-worker-cpu-low
aws cloudwatch enable-alarm-actions  --alarm-names accordion-asg-worker-cpu-low
```

### 축소 후 남은 노드 정리
축소된 노드는 Kubernetes에 `NotReady`로 남습니다.
```bash
kubectl get nodes -l accordion/node-group=asg --no-headers | awk '$2=="NotReady"{print $1}' | xargs -r kubectl delete node
```

## 주의사항
- **ASG 노드를 EC2 콘솔에서 "중지"하지 마세요.** ASG가 비정상으로 판단해서 종료 후 새로 생성합니다. 끄려면 위의 "전부 내리기" 명령을 사용하세요.
- **최소 0대에서는 CPU 자동 확장이 시작되지 않습니다.** 노드가 없으면 CPU 지표가 없기 때문입니다. 자동 확장을 쓰려면 최소 1대 이상으로 설정하세요.
- **CPU 기준은 ASG 노드만 봅니다.** 고정 Worker(`worker-1-a`, `worker-2-c`)가 바빠도 ASG 노드가 한가하면 확장되지 않습니다.
- **새 노드는 처음 8~10분 동안 대상 그룹에서 unhealthy입니다.** user_data로 Join하는 중이라 정상입니다. ALB는 unhealthy 대상에 트래픽을 보내지 않고, ASG 헬스체크는 `EC2` 기준이라 교체되지 않습니다.
- 노드 부팅 로그: EC2 → Session Manager 접속 → `sudo tail -100 /var/log/cloud-init-output.log`

## 트러블슈팅
| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `no matching EC2 VPC found` | 다른 AWS 계정 자격증명 사용 | `aws sts get-caller-identity`로 계정 확인 |
| `kubectl` → `localhost:8080 connection refused` | root에 kubeconfig 없음 | `export KUBECONFIG=/etc/kubernetes/admin.conf` |
| `kubectl top` → `Metrics API not available` / `tls: internal error` | 새 노드 kubelet-serving CSR 미승인 | CSR 승인 명령 실행 |
| 대상 그룹 `unhealthy` (`Target.Timeout`) | 노드가 아직 Join / kube-proxy 기동 중 | 노드 Ready 후 2~3분 대기 |
| 노드가 Join하지 않음 | SSM join 파라미터 없음 / 토큰 만료 | 사전 준비 3번 다시 실행 |

## 검증 결과 (2026-11-03)
| 시간 (KST) | 이벤트 | 결과 |
| --- | --- | --- |
| 20:35 | ASG가 Worker EC2 생성 (10.0.103.80, 2d) | ✅ |
| 20:37 | 클러스터 자동 Join, `asg` 라벨, Ready | ✅ |
| 20:45 | ALB 대상 그룹 자동 등록 → healthy, 노드 / ALB 경유 `/api/health` 200 | ✅ |
| 20:51 | `cpu-low` 알람 → Scale In → 인스턴스 자동 종료, 대상 그룹 자동 해제 | ✅ |

## 한계 및 개선 방향
- ASG 정책은 Pod 상태(Pending)를 모릅니다 → **Cluster Autoscaler**로 전환해서 HPA와 연동
- 축소 시 drain 없이 종료됩니다 → Cluster Autoscaler 또는 Lifecycle Hook 적용
- 새 노드마다 CSR 수동 승인이 필요합니다 → kubelet-csr-approver 도입
- 단일 AZ(2d) 구성입니다 → 다른 AZ 서브넷을 추가해서 AZ 장애 대응

## 삭제
Master D에서 실행합니다. 기존 클러스터와 ALB는 삭제되지 않습니다.
```bash
cd /home/ubuntu/hackathon/infra/terraform-asg
terraform destroy
kubectl get nodes -l accordion/node-group=asg -o name | xargs -r kubectl delete
```
