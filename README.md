## Why Kubernetes Health Checks Fail

Cluster issues show up as alerts — not root causes. You get paged for a pod
CrashLoopBackOff when the real cause is a missing secret that took down 11
deployments. Standard tooling tells you *what* failed, not *why*.

> **One command. Ten health dimensions. The fix, not just the finding.**

```bash
kubectl sentinel -n payments
```

```
══ SENTINEL REPORT ══
Context : gke-prod-eu
Scope   : namespace: payments

CRITICAL  payments/api-gateway: CrashLoopBackOff (restarts: 47)
          → kubectl rollout restart deploy/api-gateway -n payments
CRITICAL  payments: Deployment api-gateway — 0/3 replicas available
          → kubectl describe deploy/api-gateway -n payments
WARN      FailedMount: Secret api-keys not found in namespace payments
WARN      payments/api-gateway: Liveness probe failing

Summary: 2 CRITICAL · 2 WARN · 8 OK
```

---

## Install

```bash
bash install.sh          # installs to ~/bin
bash install.sh /usr/local/bin  # custom path
```

**Requirements:** `kubectl` in PATH · `jq` in PATH · a valid kubeconfig

---

## Usage

```bash
kubectl sentinel                          # full cluster check (all namespaces)
kubectl sentinel -n <namespace>           # scoped to one namespace
kubectl sentinel --context <name>         # target a specific kubeconfig context
kubectl sentinel --context <name> -n <ns> # context + namespace scope
kubectl sentinel pod/<name>               # pod deep-dive
kubectl sentinel pod/<name> -n <ns>       # pod deep-dive in specific namespace
kubectl sentinel node/<name>              # node deep-dive
kubectl sentinel --json                   # JSON output (schema v1.0)
kubectl sentinel --json -n <namespace>    # JSON output (scoped)
kubectl sentinel --no-color               # plain text (no ANSI)
kubectl sentinel --verbose                # full per-pod/per-node detail
```

## What it checks

| Section | What | CRITICAL when | WARN when |
|---------|------|---------------|-----------|
| NODES | Ready state, pressure conditions, version skew, cordoned nodes | NotReady, MemoryPressure, DiskPressure | PIDPressure, version skew, kubelet warnings |
| PODS | Phase, restart count, container state | CrashLoopBackOff, OOMKilled, ImagePullBackOff | Pending with reason, high restart count |
| PROBES | Liveness, readiness, startup probe health | Liveness failing | Readiness/startup failing, missing probes |
| WORKLOADS | Deployments, StatefulSets, DaemonSets — replica availability | 0 available replicas | Partial replica availability |
| HTTP | Services on HTTP ports — endpoint health, ingress provisioning | Empty endpoints | Not-ready endpoints |
| gRPC | Services with `grpc` port name or `appProtocol` — endpoint health | Empty endpoints | Not-ready endpoints |
| EVENTS | Warning events grouped by reason; FailedMount correlates missing secret | — | Any Warning event |
| RESOURCES | Node CPU/memory via `kubectl top` | ≥95% | ≥85% |
| PVCS | PersistentVolumeClaim state | Pending, Lost | Released |
| HPAS | HPA autoscaling constraints | minReplicas == maxReplicas | At maxReplicas ceiling |

## Flags

| Flag | Description |
|------|-------------|
| `-n <namespace>` | Scope all checks to one namespace |
| `--context <name>` | Use a specific kubeconfig context without changing the active one |
| `--json` | Emit findings as structured JSON (schema v1.0) to stdout |
| `--no-color` | Disable ANSI colour output |
| `--verbose` | Expand all grouped findings; remove WARN recommendation cap |
| `-h`, `--help` | Show usage |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | All checks passed |
| `1` | One or more WARN findings |
| `2` | One or more CRITICAL findings |

Exit codes are preserved in `--json` mode. Use them in CI:

```bash
kubectl sentinel --json -n payments > snap.json
echo "Exit: $?"  # 0=ok, 1=warn, 2=critical
```

## JSON output

Emits a single JSON object to stdout. Errors go to stderr. Safe for pipes and redirection.

```json
{
  "schema_version": "1.0",
  "generated_at": "<ISO8601>",
  "context": "<context name>",
  "scope": "all namespaces | namespace: <name>",
  "exit_code": 0,
  "summary": { "critical": 0, "warn": 3, "ok": 8 },
  "sections": [
    {
      "section": "PODS",
      "findings": [
        {
          "severity": "CRITICAL",
          "message": "<finding>",
          "recommendation": "kubectl rollout restart deploy/...",
          "last_event": { "timestamp": "...", "reason": "...", "message": "..." }
        }
      ]
    }
  ]
}
```

`--json` is not supported for `pod/<name>` or `node/<name>` deep-dive modes.

## Why the dual-layer pattern

kubectl-sentinel is the deterministic layer: it collects cluster state, applies severity
rules, and emits structured output in under 10 seconds. It works at 3am in CI with no
internet access and no external dependencies.

The `/sentinel` Claude Code skill is the reasoning layer: it reads the JSON output and
explains *why* findings matter — correlating a FailedMount event to the 11 deployments
that depend on the missing secret, or explaining that an OOMKill at the memory limit
boundary may indicate a memory leak rather than an undersized limit.

Separating them means each layer is independently testable, portable, and composable.

---

## Contributing

Issues and pull requests welcome.

Design rule: *build for the 3am reader* — every output line is written as if the reader
has been awake for 3 hours and needs to act in 5 minutes.
