#!/usr/bin/env bash
# GreenerPlatform proof program W5 gate (sentinel) — offline fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== W5: syntax =="
bash -n kubectl-sentinel

echo "== W5: EndpointSlice endpoint counts =="
bash scripts/w5_endpointslice_test.sh

echo "W5 proof gate (sentinel): PASS"
