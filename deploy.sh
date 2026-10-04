#!/usr/bin/env bash
set -euo pipefail

echo "Deploying infra..."
kubectl apply -f 00-infra/namespace.yaml
kubectl apply -f 00-infra/resource-quota.yaml
kubectl apply -f 00-infra/limit-range.yaml
kubectl apply -f 00-infra/network-policy-default-deny.yaml
kubectl apply -f 00-infra/ingress.yaml

echo "Deploying database..."
if [ ! -f 01-database/postgres/secret.yaml ]; then
  cp 01-database/postgres/secret.example.yaml 01-database/postgres/secret.yaml
fi
kubectl apply -f 01-database/postgres/
kubectl wait --for=condition=ready pod -l app=postgres -n k8s-demo --timeout=90s
sleep 3

echo "Deploying exporter..."
kubectl apply -f 01-database/exporter/

echo "Deploying backend..."
kubectl apply -f 02-backend/
kubectl wait --for=condition=ready pod -l app=backend -n k8s-demo --timeout=90s

echo "Deploying frontend..."
kubectl apply -f 03-frontend/
kubectl wait --for=condition=ready pod -l app=frontend -n k8s-demo --timeout=60s

echo "Deploying observability..."
kubectl apply -f 04-observability/prometheus/
kubectl apply -f 04-observability/grafana/
kubectl wait --for=condition=ready pod -l app=prometheus -n k8s-demo --timeout=90s
kubectl wait --for=condition=ready pod -l app=grafana -n k8s-demo --timeout=90s

echo "Deployment complete."
