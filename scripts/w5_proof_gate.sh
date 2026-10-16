#!/usr/bin/env bash
# GreenerPlatform proof program W5 gate (sentinel) — offline fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== W5: syntax =="
bash -n kubectl-sentinel

echo "== W5: EndpointSlice endpoint counts =="
bash scripts/w5_endpointslice_test.sh

echo "== W5: collection_status probe =="
bash scripts/w5_collection_status_probe.sh

echo "== W5: fixture schema =="
jq -e '.coverage.collectors[0].collection_status == "failed"' tests/fixtures/w5-failed-collector-report.json >/dev/null

echo "W5 proof gate (sentinel): PASS"
