#!/usr/bin/env bash
# Offline W5 check: EndpointSlice fallback counts ready backends when Endpoints is empty.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_KS="$ROOT/kubectl-sentinel"
[[ -f "$ROOT_KS" ]] || { echo "FAIL: kubectl-sentinel not found" >&2; exit 1; }
eval "$(sed -n '/^svc_endpoint_counts()/,/^}/p' "$ROOT_KS")"

FIX="$ROOT/tests/fixtures/w5-endpointslice-only.json"
ep_json="$(jq -c '.endpoints' "$FIX")"
eps_json="$(jq -c '.endpointslice' "$FIX")"
ns="$(jq -r '.service.metadata.namespace' "$FIX")"
name="$(jq -r '.service.metadata.name' "$FIX")"

read -r ready not_ready <<< "$(svc_endpoint_counts "$ns" "$name" "$ep_json" "$eps_json")"
if [[ "${ready:-0}" -lt 1 ]]; then
  echo "FAIL: expected ready endpoints from EndpointSlice, got ready=$ready not_ready=$not_ready"
  exit 1
fi
echo "W5 EndpointSlice fallback: ready=$ready not_ready=$not_ready"
