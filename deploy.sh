#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "  K8s Enterprise Stack - Deployment       "
echo "=========================================="

echo "[1/6] Inicjalizacja infrastruktury bazowej..."
kubectl apply -f 00-infra/namespace.yaml
kubectl apply -f 00-infra/resource-quota.yaml
kubectl apply -f 00-infra/limit-range.yaml
kubectl apply -f 00-infra/network-policy-default-deny.yaml
kubectl apply -f 00-infra/ingress.yaml

echo "[2/6] Wdrażanie bazy danych PostgreSQL..."
if [ ! -f 01-database/postgres/secret.yaml ]; then
  cp 01-database/postgres/secret.example.yaml 01-database/postgres/secret.yaml
fi
kubectl apply -f 01-database/postgres/
kubectl wait --for=condition=ready pod -l app=postgres -n k8s-demo --timeout=90s

echo "[3/6] Wdrażanie eksportera bazy danych..."
kubectl apply -f 01-database/exporter/

echo "[4/6] Wdrażanie backendu (FastAPI)..."
kubectl apply -f 02-backend/
kubectl wait --for=condition=ready pod -l app=backend -n k8s-demo --timeout=90s

echo "[5/6] Wdrażanie frontendu (Nginx)..."
kubectl apply -f 03-frontend/
kubectl wait --for=condition=ready pod -l app=frontend -n k8s-demo --timeout=60s

echo "[6/6] Wdrażanie stosu monitoringu (Prometheus & Grafana)..."
kubectl apply -f 04-observability/prometheus/
kubectl apply -f 04-observability/grafana/
kubectl wait --for=condition=ready pod -l app=prometheus -n k8s-demo --timeout=90s
kubectl wait --for=condition=ready pod -l app=grafana -n k8s-demo --timeout=90s

echo "=========================================="
echo "  Wdrożenie zakończone sukcesem!          "
echo "=========================================="
echo "Dostęp do aplikacji:"
echo "  - Frontend: http://localhost:8080/"
echo "  - Backend API: http://localhost:8080/api"
echo "  - Status gotowości: http://localhost:8080/ready"
echo ""
echo "Dostęp do Grafany:"
echo "  - Uruchom: kubectl port-forward svc/grafana-service 3000:3000 -n k8s-demo"
echo "  - Przeglądarka: http://localhost:3000 (admin / admin)"
echo "=========================================="
