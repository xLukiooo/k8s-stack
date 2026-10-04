#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "  K8s Enterprise Stack - Teardown         "
echo "=========================================="

echo "Usuwanie namespace k8s-demo oraz wszystkich zasobów..."
kubectl delete namespace k8s-demo --ignore-not-found=true

echo "Usuwanie globalnych zasobów klastra..."
kubectl delete clusterrolebinding prometheus-k8s-demo-binding --ignore-not-found=true
kubectl delete clusterrole prometheus-k8s-demo --ignore-not-found=true

echo "=========================================="
echo "  Środowisko zostało wyczyszczone!        "
echo "=========================================="
