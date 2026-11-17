# Offline evidence pack (sentinel)

kubectl-sentinel collects from a live Kubernetes API. Offline proof for this repository
covers fixture schema and collector status without a cluster.

End-to-end same-input triage (snapshot plus alert to golden JSON) lives in
[incident-triage/evidence/offline-pack](https://github.com/GreenerPlatform/incident-triage/tree/main/evidence/offline-pack).
That pack commits a kubectl-sentinel `--json` snapshot as its fixture input.

## Verify

From the repository root:

```bash
bash evidence/offline-pack/verify.sh
```

This runs the existing W5 offline fixture gates (EndpointSlice counts, collection_status
probe, failed-collector fixture schema). No kubeconfig is required.

## Limits

- These checks do not exercise a live API. Fresh collection still needs a cluster.
- Deterministic triage comparison is owned by the incident-triage offline pack.
