# kubectl-sentinel

Kubernetes cluster health checker. Runs 10 checks across nodes, pods, workloads, services, probes, events, resources, PVCs, and HPAs. Outputs a ranked report with CRITICAL/WARN/OK findings and concrete kubectl remediation commands.

Works standalone (no Claude required) and as the data source for the `/sentinel` Claude skill.

---

## Requirements

- `kubectl` in PATH with cluster access
- `jq` in PATH
- A valid kubeconfig

## Installation

```bash
bash install.sh          # installs to ~/bin
bash install.sh /usr/local/bin  # or a custom path
```

## Usage

```bash
kubectl sentinel                          # full cluster check (all namespaces)
kubectl sentinel -n <namespace>           # scoped to one namespace
kubectl sentinel --context <name>         # target a specific kubeconfig context
kubectl sentinel --context <name> -n <ns> # context + namespace scope
kubectl sentinel pod/<name>               # pod deep-dive
kubectl sentinel pod/<name> -n <ns>       # pod deep-dive in specific namespace
kubectl sentinel node/<name>              # node deep-dive
kubectl sentinel --json                   # JSON output (all namespaces)
kubectl sentinel --json -n <namespace>    # JSON output (scoped)
kubectl sentinel --no-color               # plain text (no ANSI)
kubectl sentinel --verbose                # full per-pod/per-node detail
```

## Flags

| Flag | Description |
|------|-------------|
| `-n <namespace>` | Scope all checks to one namespace |
| `--context <name>` | Use a specific kubeconfig context without changing the active one |
| `--output-format text\|json\|html` | Output format (canonical flag) |
| `--json` | Emit findings as structured JSON (alias for `--output-format json`) |
| `--html` | Emit self-contained HTML report (alias for `--output-format html`) |
| `--no-color` | Disable ANSI colour output |
| `--verbose` | Expand all grouped findings; remove WARN recommendation cap |
| `-h`, `--help` | Show usage |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | All checks passed |
| `1` | One or more WARN findings |
| `2` | One or more CRITICAL findings |

Exit codes are preserved in `--json` and `--html` modes (`exit_code` field).

## JSON output (`--json`)

Emits a single JSON object to stdout. Errors go to stderr. Safe for pipes and redirection.

Schema v1.0:
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
      "section": "NODES | PODS | PROBES | ...",
      "findings": [
        {
          "severity": "CRITICAL | WARN | OK",
          "message": "<finding>",
          "recommendation": "<kubectl command | null>",
          "last_event": { "timestamp": "...", "reason": "...", "message": "..." }
        }
      ]
    }
  ]
}
```

`--json` is not supported for `pod/<name>` or `node/<name>` deep-dive modes.

## Checks

| Section | What is checked |
|---------|----------------|
| NODES | Ready state, pressure conditions (Memory/Disk/PID), version skew, cordoned nodes, kubelet warnings |
| PODS | Failed phase, CrashLoopBackOff, OOMKilled, ImagePullBackOff, high restart count, Pending with scheduling reason |
| PROBES | Liveness failures (CRITICAL), readiness/startup failures (WARN), missing probes |
| WORKLOADS | Deployments, StatefulSets, DaemonSets — replica availability |
| HTTP | Services on HTTP ports — empty endpoints (CRITICAL), not-ready endpoints (WARN), ingress provisioning |
| gRPC | Services with `grpc` port name or `appProtocol` — endpoint health |
| EVENTS | Warning events grouped by reason; FailedMount correlates missing secret |
| RESOURCES | Node CPU/memory via `kubectl top`; WARN ≥85%, CRITICAL ≥95% |
| PVCS | Pending/Lost → CRITICAL, Released → WARN |
| HPAS | `minReplicas == maxReplicas` (cannot autoscale), at `maxReplicas` ceiling |

## Claude skill

Install `kubectl-sentinel`, then invoke the `/sentinel` Claude Code skill. It uses this tool as its primary data source:

```bash
kubectl-sentinel --json [-n <namespace>] [--context <name>]
```

The skill falls back to direct kubectl calls if the script is not installed.
