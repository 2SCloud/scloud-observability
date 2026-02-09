# Grafana Observability Stack on k3s

This README explains how to deploy and manage a **Grafana observability stack**
(Grafana, Mimir, Loki, Tempo, Alloy) on **k3s** using automated deployment scripts.

---

## Components

- **Grafana**: UI & dashboards  
- **Mimir**: Metrics backend (Prometheus-compatible)  
- **Loki**: Logs backend  
- **Tempo**: Traces backend (OTLP)  
- **Alloy**: Collector (metrics, logs, traces)

Namespace: `scloud-observability`

---

## Quick Start (Scripts usages)

### 1. Deploy the Stack

Run the deployment script to install all components:

```bash
./deploy-scloud-observability.sh
```

This script will:
- Create the `scloud-observability` namespace
- Add and update Helm repositories
- Deploy all components (Mimir, Loki, Tempo, Alloy, Grafana)
- Wait for pods to be ready
- Start port-forwards in background
- Run health checks

### 2. Clean Up

To completely remove the stack:

```bash
./clean.sh
```

This script will:
- Stop all port-forwards
- Uninstall all Helm releases
- Delete the namespace
- Clean up log files
- Verify cleanup completion

---

## Access Points

After deployment, services are accessible at:

- **Grafana**: http://localhost:3000 (credentials: admin/admin)
- **Mimir**: http://localhost:8080
- **Loki**: http://localhost:3100
- **Tempo**: http://localhost:4318
- **Alloy**: http://localhost:12345

---

## Health Checks

Verify services are running:

```bash
# Grafana
curl http://localhost:3000/api/health

# Mimir
curl http://localhost:8080/prometheus/api/v1/status/buildinfo

# Loki
curl http://localhost:3100/ready
```

---

## Send Test Data

### Test Metric to Mimir

```bash
kubectl -n scloud-observability delete pod promtool --force --grace-period=0 2>/dev/null || true

kubectl -n scloud-observability run promtool \
  --restart=Never \
  --image=prom/prometheus:v2.54.1 \
  -- sh -lc '
cat >/tmp/test.prom <<EOF2
test_metric{job="manual",instance="cli"} 1
EOF2

promtool tsdb create-blocks-from openmetrics /tmp/test.prom /tmp/tsdb
promtool remote-write \
  --url=http://mimir-k3s-gateway.scloud-observability.svc:80/api/v1/push \
  /tmp/tsdb
'
```

### Verify Metric

```bash
curl -G http://localhost:8080/prometheus/api/v1/query \
  --data-urlencode "query=test_metric"
```

Or via Grafana UI:
1. Open http://localhost:3000
2. Navigate to Explore → Prometheus
3. Query: `test_metric`

---

## Manual Operations

### Stop Port-Forwards

```bash
pkill -f "kubectl -n scloud-observability port-forward"
```

### Manual Deployment (Step by Step)

If you prefer manual control:

```bash
# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace scloud-observability 2>/dev/null || true

# Deploy components
helm upgrade --install mimir grafana/mimir-distributed \
  -n scloud-observability -f grafana/mimir-values.yaml

helm upgrade --install loki grafana/loki \
  -n scloud-observability -f grafana/loki-values.yaml

helm upgrade --install tempo grafana/tempo \
  -n scloud-observability -f grafana/tempo-values.yaml

helm upgrade --install alloy grafana/alloy \
  -n scloud-observability -f grafana/alloy-values.yaml

helm upgrade --install grafana grafana/grafana \
  -n scloud-observability -f grafana/grafana-values.yaml

# Start port-forwards
kubectl -n scloud-observability port-forward svc/grafana 3000:80 > /tmp/pf-grafana.log 2>&1 &
kubectl -n scloud-observability port-forward svc/loki 3100:3100 > /tmp/pf-loki.log 2>&1 &
kubectl -n scloud-observability port-forward svc/tempo 4318:4318 > /tmp/pf-tempo.log 2>&1 &
kubectl -n scloud-observability port-forward svc/mimir-k3s-gateway 8080:80 > /tmp/pf-mimir.log 2>&1 &
kubectl -n scloud-observability port-forward svc/alloy 12345:12345 > /tmp/pf-alloy.log 2>&1 &
```

---

## Troubleshooting

### Check Pod Status

```bash
kubectl -n scloud-observability get pods
```

### View Port-Forward Logs

```bash
tail -f /tmp/pf-grafana.log
tail -f /tmp/pf-mimir.log
tail -f /tmp/pf-loki.log
tail -f /tmp/pf-tempo.log
tail -f /tmp/pf-alloy.log
```

### Check Active Port-Forwards

```bash
ps aux | grep "kubectl.*port-forward.*scloud-observability"
```

### Cleanup Verification

After running `clean.sh`, verify:
- Namespace deleted: `kubectl get namespace scloud-observability`
- No active port-forwards: `ps aux | grep port-forward`
- Helm releases removed: `helm list -n scloud-observability`

---

## Configuration Files

All configuration files are located in the `./grafana/` directory:
- `grafana-values.yaml`
- `mimir-values.yaml`
- `loki-values.yaml`
- `tempo-values.yaml`
- `alloy-values.yaml`

---

## Expected State

After successful deployment:
- Grafana UI accessible at http://localhost:3000
- All health checks passing
- Metrics queryable via Mimir
- Mimir ring healthy
- Loki & Tempo ready
- Alloy collecting telemetry data