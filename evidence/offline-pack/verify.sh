#!/usr/bin/env bash
# Offline evidence checks for kubectl-sentinel fixtures. No cluster access.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required" >&2
  exit 1
fi

echo "== offline-pack: W5 fixture gates =="
bash scripts/w5_proof_gate.sh

echo "== offline-pack: failed-collector fixture fields =="
jq -e '
  (.coverage.collectors | type == "array") and
  (.coverage.collectors[0].collection_status == "failed")
' tests/fixtures/w5-failed-collector-report.json >/dev/null

echo "offline evidence pack (sentinel fixtures): PASS"
echo "End-to-end triage determinism: https://github.com/GreenerPlatform/incident-triage/tree/main/evidence/offline-pack"
