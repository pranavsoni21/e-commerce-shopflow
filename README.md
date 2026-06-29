# ShopFlow — Cloud-Native E-Commerce Platform

A production-grade DevOps portfolio project demonstrating a full cloud-native deployment pipeline on AWS. Four Python microservices deployed to EKS via GitOps, with infrastructure managed entirely through Terraform.

---

## What This Project Demonstrates

- Infrastructure as Code with Terraform (modular, remote state)
- Container orchestration with Kubernetes (EKS)
- GitOps deployment with ArgoCD (zero manual kubectl applies)
- CI/CD pipeline with GitHub Actions (test → scan → build → push → deploy)
- Image vulnerability scanning with Trivy
- AWS services: EKS, ECR, RDS, IAM, SES, VPC

---

## Architecture

<img width="2011" height="1401" alt="arch_diagram_shopflow" src="https://github.com/user-attachments/assets/236b2bc0-a4b8-4c7b-8aba-4f1573ad7e08" />

```
Developer
    │ git push
    ▼
GitHub (monorepo)
    │ triggers
    ▼
GitHub Actions ──────────────────────── updates image tag in manifest
    │ push image                               │
    ▼                                          ▼
AWS ECR                              Git (kustomization.yaml)
    │                                          │
    │                              ArgoCD watches & syncs
    │                                          │
    └──────────────────┬────────────────────────┘
                       ▼
              EKS Cluster (ap-south-1)
              ┌─────────────────────────────┐
              │  shopflow namespace          │
              │  ┌──────────┐ ┌───────────┐ │
              │  │ user-svc │ │product-svc│ │
              │  │  ×2 pods │ │  ×2 pods  │ │
              │  └──────────┘ └───────────┘ │
              │  ┌──────────┐ ┌───────────┐ │
              │  │ order-svc│ │ notif-svc │ │
              │  │  ×2 pods │ │  ×1 pod   │ │
              │  └──────────┘ └───────────┘ │
              └─────────────────────────────┘
                       │
                       ▼
              RDS PostgreSQL 15
              userdb · productdb · orderdb
```

---

## Services

| Service | Port | Description | Database |
|---|---|---|---|
| user-svc | 8000 | Auth, registration, JWT login | userdb |
| product-svc | 8000 | Product catalog | productdb |
| order-svc | 8000 | Order placement and tracking | orderdb |
| notification-svc | 8000 | Email notifications via AWS SES | none |

Each service exposes:
- `GET /health` — liveness and readiness probe endpoint
- `GET /docs` — Swagger UI (auto-generated)

---

## Repository Structure

```
shopflow/
├── services/
│   ├── user/               # FastAPI auth service
│   ├── product/            # FastAPI product catalog
│   ├── order/              # FastAPI order service
│   └── notification/       # FastAPI email service
├── infra/
│   ├── terraform/
│   │   ├── main.tf         # Root module — wires all modules together
│   │   ├── variables.tf
│   │   ├── terraform.tfvars  # Not committed — contains secrets
│   │   └── modules/
│   │       ├── vpc/        # VPC, subnets, NAT, route tables
│   │       ├── ecr/        # ECR repos with lifecycle policies
│   │       ├── eks/        # EKS cluster, node group, addons, OIDC
│   │       ├── iam/        # Cluster role, node role, IRSA roles
│   │       └── rds/        # RDS PostgreSQL, subnet group, security group
│   ├── k8s/
│   │   ├── base/           # Base manifests (Deployment, Service, HPA, SA)
│   │   │   ├── user-svc/
│   │   │   ├── product-svc/
│   │   │   ├── order-svc/
│   │   │   └── notification-svc/
│   │   └── overlays/
│   │       ├── production/ # Production image tags, kustomization
│   │       └── staging/    # Staging replica counts
│   └── argocd/             # ArgoCD Application manifests
│       ├── root-app.yaml   # App of Apps — deploy this once
├       ├── frontend-app.yaml
│       ├── user-svc-app.yaml
│       ├── product-svc-app.yaml
│       ├── order-svc-app.yaml
│       └── notification-svc-app.yaml
└── .github/
    └── workflows/
        ├── user-svc.yml
        ├── frontend.yml
        ├── product-svc.yml
        ├── order-svc.yml
        └── notification-svc.yml
```

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform ~> 1.14
- kubectl
- Docker
- GitHub account with the repo forked/cloned

---

## Deployment Guide

### 1. Bootstrap Terraform state backend

I created remote state on HCP Terraform but for demonstration we can create it using s3 and dynamodb. 
Before anything else, create the S3 bucket and DynamoDB table for remote state. Do this once manually:

```bash
aws s3 create-bucket \
  --bucket shopflow-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws dynamodb create-table \
  --table-name shopflow-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

### 2. Configure variables

Copy and fill in the variables file:

```bash
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
```

Required values:
```hcl
project_name = "shopflow"
environment  = "production"
aws_region   = "ap-south-1"
db_username  = "your-db-username"
db_password  = "your-strong-password"
github_org   = "your-github-username"
github_repo  = "shopflow"
```

### 3. Apply Terraform

```bash
cd infra/terraform

# Apply in dependency order
terraform init
terraform apply -target=module.kms
terraform apply -target=module.vpc
terraform apply -target=module.ecr
terraform apply -target=module.iam
terraform apply -target=module.eks
terraform apply -target=module.rds

# Or apply everything at once (Terraform resolves dependencies)
terraform apply
```

### 4. Configure kubectl

```bash
aws eks update-kubeconfig \
  --name shopflow-cluster \
  --region ap-south-1
```

### 5. Create databases inside RDS

```bash
# Connect to RDS from inside the cluster
kubectl run pg-setup \
  --image=postgres:15-alpine \
  --restart=Never \
  --rm -it \
  -n default \
  -- psql -h <rds-endpoint> -U <db-username> -d shopflow -p 5432

# Inside psql:
CREATE DATABASE userdb;
CREATE DATABASE productdb;
CREATE DATABASE orderdb;
\q
```

Get the RDS endpoint:
```bash
terraform output db_host
```

### 6. Create Kubernetes secrets

```bash
RDS_HOST=$(terraform output -raw db_host)

kubectl create secret generic user-svc-secrets \
  --namespace=shopflow \
  --from-literal=database_url="postgresql://{db_username}:{db_password}@${RDS_HOST}:5432/userdb?sslmode=require" \
  --from-literal=jwt_secret="your-jwt-secret"

kubectl create secret generic product-svc-secrets \
  --namespace=shopflow \
  --from-literal=database_url="postgresql://{db_username}:{db_password}@${RDS_HOST}:5432/productdb?sslmode=require"

kubectl create secret generic order-svc-secrets \
  --namespace=shopflow \
  --from-literal=database_url="postgresql://{db_username}:{db_password}@${RDS_HOST}:5432/orderdb?sslmode=require"

kubectl create secret generic notification-svc-secrets \
  --namespace=shopflow \
  --from-literal=aws_region="ap-south-1" \
  --from-literal=ses_sender_email="noreply@yourdomain.com"
```

### 7. Set GitHub Actions secrets

In your GitHub repo → Settings → Secrets and Variables → Actions:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS user ACCESS KEY ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS user SECRET ACCESS KEY |
| `ECR_REGISTRY` | `<account-id>.dkr.ecr.ap-south-1.amazonaws.com` |

Variables (non-sensitive):

| Variable | Value |
|---|---|
| `AWS_REGION` | `ap-south-1` |

### 8. Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

### 9. Deploy with ArgoCD

Apply the root app once — ArgoCD manages everything else:

```bash
kubectl apply -f infra/argocd/root-app.yaml
```

Access the ArgoCD UI:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080  (admin / <password from step 8>)
```

### 10. Trigger first pipeline run

Push any change to a service to trigger the GitHub Actions pipeline:

```bash
git commit --allow-empty -m "trigger: initial pipeline run"
git push
```

Within a few minutes all pods should be `1/1 Running`.

---

## Verifying the Deployment

```bash
# All pods running
kubectl get pods -n shopflow

# All services reachable
kubectl get svc -n shopflow

# HPA configured
kubectl get hpa -n shopflow

# Test an endpoint
kubectl port-forward svc/product-svc -n shopflow 8002:8000 &
curl http://localhost:8002/health
curl http://localhost:8002/api/v1/products
```

---

## CI/CD Pipeline

Each service has its own workflow in `.github/workflows/`. A push to `main` that touches `services/<name>/**` triggers:

```
1. build and scan → Build docker image and Trivy image scan (fails on CRITICAL CVEs)
2. push → build + push image to ECR (SHA tag)
3. manifest → kustomize edit to update image tag in Git
            → ArgoCD detects commit → rolls out new pods
```

Pull requests run step 1 only — no image push, no deploy.

---

## AWS Cost Estimate (ap-south-1)

| Resource | Spec | Monthly |
|---|---|---|
| EKS control plane | — | ~$73 |
| EC2 nodes | 2× c7i-flex.large | ~$80 |
| RDS | db.t3.micro PostgreSQL | ~$15 |
| NAT Gateway | 1× | ~$32 |
| ECR | ~5GB storage | ~$0.50 |
| **Total** | | **~$203/month** |

To reduce cost during development: scale node group to 0 overnight, or destroy and recreate the cluster between sessions.

---

## Known Limitations

- Secrets are managed manually via `kubectl create secret` — Vault integration is a planned next step
- No ingress controller configured — services are accessed via port-forward
- Single NAT Gateway (not HA — add one per AZ for production)
- RDS has `deletion_protection = false` for dev convenience — set to `true` before real data

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.12, FastAPI |
| Container | Docker |
| Registry | AWS ECR |
| Orchestration | Kubernetes (EKS 1.30) |
| IaC | Terraform |
| GitOps | ArgoCD |
| CI/CD | GitHub Actions |
| Database | PostgreSQL 18 (RDS) |
| Email | AWS SES |
| Manifest management | Kustomize |
