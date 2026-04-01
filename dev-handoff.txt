# ShopFlow — Developer Handoff

## Overview

ShopFlow is a cloud-native e-commerce backend made up of 4 Python/FastAPI microservices.
This README is written for the DevOps engineer taking over deployment.

---

## Services

| Service | Port (local) | Description |
|---|---|---|
| user-svc | 8001 | Auth, registration, JWT login |
| product-svc | 8002 | Product catalog |
| order-svc | 8003 | Order placement and tracking |
| notification-svc | 8004 | Email notifications via AWS SES |

---

## Running Locally

```bash
docker compose up --build
```

All 4 services + 3 PostgreSQL databases will start.

Swagger UI (interactive API docs) available at:
- http://localhost:8001/docs  (user-svc)
- http://localhost:8002/docs  (product-svc)
- http://localhost:8003/docs  (order-svc)
- http://localhost:8004/docs  (notification-svc)

Health checks:
- http://localhost:8001/health
- http://localhost:8002/health
- http://localhost:8003/health
- http://localhost:8004/health

---

## Running Tests

Each service has its own test suite using pytest + SQLite (no real DB needed).

```bash
# From repo root
cd services/user   && pip install -r requirements.txt && pytest tests/ -v
cd services/product && pip install -r requirements.txt && pytest tests/ -v
cd services/order   && pip install -r requirements.txt && pytest tests/ -v
cd services/notification && pip install -r requirements.txt && pytest tests/ -v
```

---

## Environment Variables

### user-svc
| Variable | Required | Description |
|---|---|---|
| DATABASE_URL | Yes | PostgreSQL connection string |
| JWT_SECRET | Yes | Secret key for signing JWTs — use Vault in prod |

### product-svc
| Variable | Required | Description |
|---|---|---|
| DATABASE_URL | Yes | PostgreSQL connection string |

### order-svc
| Variable | Required | Description |
|---|---|---|
| DATABASE_URL | Yes | PostgreSQL connection string |
| NOTIFICATION_SVC_URL | Yes | Internal URL of notification-svc |

### notification-svc
| Variable | Required | Description |
|---|---|---|
| AWS_REGION | Yes | AWS region for SES |
| SES_SENDER_EMAIL | Yes | Verified SES sender address |

---

## Inter-Service Communication

```
User  ──────────────────────────────────────────► user-svc
Browser ──────────────────────────────────────── product-svc
                                                  order-svc
                                                     │
                                         (internal)  ▼
                                             notification-svc
                                                     │
                                                     ▼
                                                  AWS SES
```

order-svc calls notification-svc internally via HTTP.
If notification-svc is down, orders still succeed (fire-and-forget).

---

## Database

- Each service owns its own PostgreSQL database (no shared DB)
- Schema is auto-created on startup via SQLAlchemy
- In production: use AWS RDS PostgreSQL 15, private subnet only
- Credentials must come from HashiCorp Vault (not env vars hardcoded)

---

## Docker Images

Each service has its own Dockerfile at `services/<name>/Dockerfile`.

Build pattern:
```bash
docker build -t shopflow/user-svc:latest services/user/
```

Images must be pushed to AWS ECR. Repos expected:
- `shopflow/user`
- `shopflow/product`
- `shopflow/order`
- `shopflow/notification`

---

## Notes for DevOps

1. **JWT_SECRET** must be rotated via Vault — never hardcode it
2. **SES sender email** must be verified in AWS SES before notification-svc works
3. order-svc depends on notification-svc being reachable, but won't crash if it isn't
4. All services expose `/health` for Kubernetes liveness/readiness probes
5. All services are designed to run as non-root (appuser) inside the container
6. Services are stateless — safe to run multiple replicas behind a load balancer
