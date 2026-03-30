# Configuration 5 — K8s + Auto-scaling + Blue/Green

## Overview

This configuration deploys **OpenEMR** on Kubernetes with **Horizontal Pod Autoscaler (HPA)** and **Blue/Green deployment strategy**, combining zero-downtime deployments with automatic scaling under variable load.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│               Kubernetes Cluster                 │
│  Namespace: openemr                              │
│                                                  │
│  ┌──────────────┐    ┌──────────────┐            │
│  │  OpenEMR     │    │  OpenEMR     │            │
│  │  Blue (live) │    │  Green       │            │
│  │  1-5 pods    │    │  (standby)   │            │
│  └──────┬───────┘    └──────────────┘            │
│         │                                        │
│  ┌──────▼───────┐    ┌──────────────┐            │
│  │   Service    │    │     HPA      │            │
│  │  NodePort    │    │ CPU > 60%    │            │
│  │  port 31000  │    │ max 5 pods   │            │
│  └──────────────┘    └──────────────┘            │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │           MySQL (MariaDB)                │    │
│  │           ClusterIP :3306                │    │
│  └──────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

---

## Files Structure

```
config5/
├── k8s/
│   ├── mysql-deployment.yaml     # MariaDB database + ClusterIP service
│   ├── openemr-blue.yaml         # Blue deployment (active traffic)
│   ├── openemr-green.yaml        # Green deployment (standby)
│   ├── openemr-service.yaml      # NodePort service (selector: version=blue)
│   └── hpa.yaml                  # HPA: min=1, max=5, CPU target=60%
├── tests/
│   ├── smoke-test.js             # 5 VUs, 1 min
│   ├── load-test.js              # 100 VUs, 9 min
│   ├── stress-test.js            # 500 VUs, 8 min
│   └── results/
│       ├── smoke-test-results.json
│       ├── load-test-results.json
│       └── stress-test-results.json
└── README.md
```

---

## Deployment

### Prerequisites
- Minikube running
- kubectl configured
- metrics-server enabled

### Deploy

```bash
# Create namespace
kubectl create namespace openemr

# Deploy database
kubectl apply -f config5/k8s/mysql-deployment.yaml

# Deploy Blue/Green
kubectl apply -f config5/k8s/openemr-blue.yaml
kubectl apply -f config5/k8s/openemr-green.yaml

# Deploy service (points to Blue by default)
kubectl apply -f config5/k8s/openemr-service.yaml

# Deploy HPA
kubectl apply -f config5/k8s/hpa.yaml

# Enable metrics server
minikube addons enable metrics-server
```

### Access the application

```bash
minikube service openemr -n openemr
```

---

## Blue/Green Switch

```bash
# Switch traffic to Green (zero downtime)
kubectl patch service openemr -n openemr -p '{"spec":{"selector":{"app":"openemr","version":"green"}}}'

# Switch back to Blue
kubectl patch service openemr -n openemr -p '{"spec":{"selector":{"app":"openemr","version":"blue"}}}'

# Verify active version
kubectl get service openemr -n openemr -o jsonpath='{.spec.selector}'
```

---

## HPA Configuration

| Parameter | Value |
|---|---|
| Min Replicas | 1 |
| Max Replicas | 5 |
| CPU Threshold | 60% |
| Scale Target | openemr-blue |

### HPA Behavior During Stress Test

| Phase | CPU Usage | Replicas |
|---|---|---|
| Idle | 3% | 1 |
| Load Start | 163% | 1→3 |
| Peak | 250% | 5 |
| Cool Down | 83% | 5 |
| After Test | 6% | 1 |

---

## Load Tests

Run with [K6](https://k6.io/):

```bash
# Smoke test
k6 run tests/smoke-test.js

# Load test
k6 run tests/load-test.js

# Stress test
k6 run tests/stress-test.js
```

---

## Application

**OpenEMR v7.0.2** — World's most popular open source Electronic Health Record system
- Used in 100+ countries, 200M+ patients
- Stack: PHP + Apache + MariaDB
- Docker image: `openemr/openemr:7.0.2`
