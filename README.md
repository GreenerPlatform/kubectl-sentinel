<div align="center">
  <img src="docs/banner.svg" alt="kubectl-sentinel" width="100%"/>
</div>

<div align="center">
  <img src="https://img.shields.io/github/actions/workflow/status/GreenerPlatform/kubectl-sentinel/ci.yml?style=flat-square&label=CI" alt="CI"/>
  <img src="https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white" alt="bash"/>
  <img src="https://img.shields.io/badge/kubectl-plugin-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="kubectl plugin"/>
  <img src="https://img.shields.io/badge/output-JSON%20%7C%20text%20%7C%20HTML-lightgrey?style=flat-square" alt="output formats"/>
  <img src="https://img.shields.io/badge/CI%20safe-exit%200%2F1%2F2-brightgreen?style=flat-square" alt="exit codes"/>
  <img src="https://img.shields.io/github/license/GreenerPlatform/kubectl-sentinel?style=flat-square" alt="license"/>
</div>

---

## Why Kubernetes Health Checks Fail

Cluster issues show up as alerts — not root causes. You get paged for a pod
CrashLoopBackOff when the real cause is a missing secret that took down 11
deployments. Standard tooling tells you *what* failed, not *why*.

> **One command. 15 health dimensions. Every finding ships with the fix command.**

```bash
kubectl sentinel -n payments
```

```
══ SENTINEL REPORT ══
Context : prod-cluster
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
# krew (recommended — kubectl's plugin manager)
kubectl krew install sentinel
kubectl sentinel

# or from source
git clone https://github.com/GreenerPlatform/kubectl-sentinel
cd kubectl-sentinel && bash install.sh /usr/local/bin
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
kubectl sentinel --json                   # JSON output (schema v1.1)
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
| JOBS | Jobs & CronJobs — completion, backoff, scheduling | Job `Failed` condition | Retrying (no success yet), suspended CronJob |
| PDBS | PodDisruptionBudgets — protection & drain safety | `currentHealthy < desiredHealthy` | `disruptionsAllowed == 0` (blocks drains) |
| QUOTAS | ResourceQuota saturation (integer resources) | ≥100% (objects rejected) | ≥90% |
| DNS | CoreDNS/kube-dns availability (kube-system, cluster-wide) | 0 replicas available | Degraded (partial) |
| CERTS | cert-manager Certificate expiry & readiness | Expired / ≤7d / not Ready | ≤21d to expiry |

PODS also flags containers with **no CPU request** (WARN); WORKLOADS also flags **stuck rollouts** (`Progressing=False` / `ProgressDeadlineExceeded`, WARN).

## Flags

| Flag | Description |
|------|-------------|
| `-n <namespace>` | Scope all checks to one namespace |
| `--context <name>` | Use a specific kubeconfig context without changing the active one |
| `--json` | Emit findings as structured JSON (schema v1.1) to stdout |
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
  "schema_version": "1.1",
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
          "id": "POD-CRASHLOOP",
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

Each finding carries a **stable `id`** (e.g. `POD-CRASHLOOP`, `PDB-BREACHED`) — a durable
handle for a finding *type* that stays constant across runs even if the message is reworded.
Use it to reference, group, suppress, or correlate findings, and as a typed key for an AI/agent
to reason over instead of parsing message text.

`--json` is not supported for `pod/<name>` or `node/<name>` deep-dive modes.

## Works with incident-triage

Pipe the JSON output directly into [incident-triage](https://github.com/GreenerPlatform/incident-triage)
to get a classified causation chain and a ready-to-run P1 fix command:

```bash
kubectl sentinel --json -n payments > snap.json
incident-triage --sentinel-json snap.json --alert "payments API 503 since 14:30"
```

kubectl-sentinel collects the cluster state in a single pass. incident-triage classifies
the alert, scores each sentinel finding by relevance, and outputs a root cause, causation
chain, and P1 command — sourced directly from the `recommendation` field in the sentinel JSON.

## Using it from an AI agent (any runtime)

Two paths, both vendor-neutral:

**1. MCP server (recommended).** The [GreenerPlatform MCP server](https://github.com/GreenerPlatform)
exposes `sentinel` as a tool to any MCP client — Cursor, Claude Desktop, VS Code, Windsurf,
or a custom agent. Install once; it works everywhere.

**2. Reference agent skill.** [`skills/SKILL.md`](skills/SKILL.md) is a reference reasoning-layer
integration (a Claude Code command). Copy it into your agent's command directory:

```bash
cp skills/SKILL.md /path/to/your-project/.claude/commands/sentinel.md
```

```
/sentinel -n payments
/sentinel pod/api-gateway-abc123 -n payments
/sentinel node/worker-1
```

The reasoning layer reads the JSON and explains *why* findings matter — correlating a
FailedMount to every deployment blocked by the same missing secret, and distinguishing an
OOMKill that needs a higher limit from one that signals a memory leak.

## Why the dual-layer pattern

kubectl-sentinel is the deterministic layer: it collects cluster state, applies severity
rules, and emits structured output in a single pass. It runs in CI with no external
dependencies — no internet calls, no SaaS, no LLM in the loop.

The reasoning layer (an agent, via MCP or the reference skill) reads that JSON and explains
*why* findings matter. It is bounded by the evidence the CLI collected — it reasons over
facts, it does not guess at cluster state.

Separating them means each layer is independently testable, portable, and composable.

---

## Contributing

Issues and pull requests welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

Design rule: every output line names the finding and the command that resolves it.
