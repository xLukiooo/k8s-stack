#!/usr/bin/env bash
set -euo pipefail

DURATION=60
CONCURRENCY=5
ENDPOINT="http://localhost:8080/api/cpu-burn?duration_seconds=2"

echo "=========================================="
echo "  Generowanie obciążenia CPU dla HPA     "
echo "  Cel: ${ENDPOINT}                       "
echo "  Czas trwania: ${DURATION}s             "
echo "  Współbieżność: ${CONCURRENCY} wątków   "
echo "=========================================="

END_TIME=$((SECONDS + DURATION))

for ((i = 0; i < CONCURRENCY; i++)); do
  (
    while [ $SECONDS -lt $END_TIME ]; do
      curl -s "${ENDPOINT}" > /dev/null || true
    done
  ) &
done

echo "Ruch jest generowany w tle."
echo "Obserwuj skalowanie w osobnym terminalu poleceniem:"
echo "kubectl get hpa backend-hpa -n k8s-demo -w"
echo ""

wait

echo "Test zakończony!"
