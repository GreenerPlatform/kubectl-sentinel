#!/usr/bin/env bash
# Fail if emit_json hard-codes collection_status to complete for every finding.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if grep -E 'collection_status:"complete"' "$ROOT/kubectl-sentinel" >/dev/null 2>&1; then
  echo "FAIL: hard-coded collection_status:\"complete\" still present in kubectl-sentinel"
  exit 1
fi
if ! grep -q 'JSON_COLL_STATUS' "$ROOT/kubectl-sentinel"; then
  echo "FAIL: JSON_COLL_STATUS tracking missing"
  exit 1
fi
if ! grep -q 'coverage:{collectors' "$ROOT/kubectl-sentinel"; then
  echo "FAIL: coverage manifest missing from JSON emit"
  exit 1
fi
echo "W5 collection_status probe: PASS"
