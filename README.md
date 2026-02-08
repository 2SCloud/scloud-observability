# Grafana Observability Stack on k3s

This README explains how to run and validate a **Grafana observability stack**
(Grafana, Mimir, Loki, Tempo, Alloy) on **k3s**, with **all services exposed via
background port-forwards**, and how to **send test data**.

---

## Components

- Grafana: UI & dashboards  
- Mimir: Metrics backend (Prometheus-compatible)  
- Loki: Logs backend  
- Tempo: Traces backend (OTLP)  
- Alloy: Collector (metrics, logs, traces)

Namespace used throughout this guide: \`observability\`

---

## 1. Namespace

Create the namespace (safe to run multiple times):

`kubectl create namespace observability 2>/dev/null || true`

---

## 2. Start Port-Forwards (Background)

### Grafana

```
kubectl -n observability port-forward svc/grafana 3000:80 > /tmp/pf-grafana.log 2>&1 &
```

### Loki
```
kubectl -n observability port-forward svc/loki 3100:3100 > /tmp/pf-loki.log 2>&1 &
```

### Tempo
```
kubectl -n observability port-forward svc/tempo 4318:4318 > /tmp/pf-tempo.log 2>&1 &
```

### Mimir
```
kubectl -n observability port-forward svc/mimir-k3s-gateway 8080:80 > /tmp/pf-mimir.log 2>&1 &
```

Check background jobs:
jobs

---

## 3. Health Checks

Grafana:
`curl http://localhost:3000/api/health`

Mimir:
`curl http://localhost:8080/prometheus/api/v1/status/buildinfo`

Tempo:
`curl http://localhost:4318/v1/traces`

---

## 4. Send Test Metric to Mimir
```
kubectl -n observability delete pod promtool --force --grace-period=0 2>/dev/null || true

kubectl -n observability run promtool \
  --restart=Never \
  --image=prom/prometheus:v2.54.1 \
  -- sh -lc '
cat >/tmp/test.prom <<EOF2
test_metric{job="manual",instance="cli"} 1
EOF2

promtool tsdb create-blocks-from openmetrics /tmp/test.prom /tmp/tsdb
promtool remote-write \
  --url=http://mimir-k3s-gateway.observability.svc:80/api/v1/push \
  /tmp/tsdb
'
```
---

## 5. Verify Metric
```
curl -G http://localhost:8080/prometheus/api/v1/query \
  --data-urlencode "query=test_metric"
  ```

---

## 6. Grafana UI

Open http://localhost:3000  
Explore → Prometheus → query: test_metric

---

## 7. Stop All Port-Forwards

`pkill -f "kubectl -n observability port-forward"`

---

## Expected State

- Grafana UI accessible
- Metrics visible
- Mimir ring healthy
- Loki & Tempo ready
- Alloy collecting
EOF
