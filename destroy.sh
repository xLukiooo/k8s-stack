#!/usr/bin/env bash
set -euo pipefail

echo "Deleting namespace k8s-demo..."
kubectl delete namespace k8s-demo --ignore-not-found=true

echo "Deleting prometheus cluster RBAC..."
kubectl delete clusterrolebinding prometheus-k8s-demo-binding --ignore-not-found=true
kubectl delete clusterrole prometheus-k8s-demo --ignore-not-found=true

echo "Cleanup complete."
