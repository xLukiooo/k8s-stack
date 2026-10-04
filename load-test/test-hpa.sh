#!/usr/bin/env bash
set -euo pipefail

DURATION=${1:-60}
CONCURRENCY=${2:-5}
ENDPOINT=${3:-"http://localhost:8080/api/cpu-burn?duration_seconds=2"}

echo "Running load test: ${CONCURRENCY} workers -> ${ENDPOINT} for ${DURATION}s"

END_TIME=$((SECONDS + DURATION))

for ((i = 0; i < CONCURRENCY; i++)); do
  (
    while [ $SECONDS -lt $END_TIME ]; do
      curl -s "${ENDPOINT}" > /dev/null || true
    done
  ) &
done

wait
echo "Done."
