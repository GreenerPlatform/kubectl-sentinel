---
name: sentinel
description: >
  Kubernetes cluster health checker — nodes, pods, workloads, services, probes,
  events, resources, PVCs, HPAs. Run /sentinel to observe cluster state, identify
  CRITICALs, and get ranked kubectl remediation commands. Use for incident triage,
  pre-deploy checks, or routine health review.
compatibility: Requires kubectl and jq. kubectl-sentinel script must be installed
  (run `bash install.sh ~/bin` from the kubectl-sentinel repo) for the primary data path.
allowed-tools: Bash(kubectl-sentinel:*) mcp__kubernetes__kubectl_context mcp__kubernetes__ping mcp__kubernetes__kubectl_get mcp__kubernetes__kubectl_describe mcp__kubernetes__kubectl_logs mcp__kubernetes__kubectl_generic mcp__kubernetes__kubectl_rollout mcp__kubernetes__kubectl_scale
---

**Arguments:** $ARGUMENTS

## Argument parsing

- Empty → full cluster check, all namespaces
- `-n <namespace>` → scope all checks to that namespace
- `--context <name>` → target a specific kubeconfig context without switching the active one
- `pod/<name>` (optionally with `-n <namespace>`) → deep-dive on that specific pod
- `node/<name>` → deep-dive on that specific node

---

## Phase 0 — Pre-flight

Run all three checks in order. Stop at the first failure — do not proceed.

**Step 1 — Context.**
`mcp__kubernetes__kubectl_context(operation="get")`
If no active context: `ERROR: No kubectl context configured. Run kubectl config use-context <name>, then retry.`

**Step 2 — API reachability.**
`mcp__kubernetes__ping()`
If ping fails: `ERROR: Cannot reach the Kubernetes API server for context <context>. Check VPN/proxy.`

**Step 3 — Credential validation.**

Ping uses the MCP server's own connection and does not exercise the kubectl credential chain (e.g. gke-gcloud-auth-plugin, kubelogin, oidc). Validate the credential chain separately:

```bash
kubectl get ns --request-timeout=5s 2>&1 | head -3
```

- If output lists namespaces → credentials valid, continue
- If output contains `exec: executable ... failed` or `Reauthentication` or `credentials` → credentials expired

On credential failure, stop with:
```
ERROR: kubectl credential chain failed — cannot collect cluster state.
<paste the first error line>
Refresh credentials (e.g. `gcloud auth login`, `az aks get-credentials`, or `kubelogin`) then re-run /sentinel.
```

Do not proceed to Phase 1a/1b with expired credentials.

**Step 4 — Tool availability.**
```bash
command -v kubectl-sentinel && echo "kubectl-sentinel: found" || echo "kubectl-sentinel: not found"
command -v glow && echo "glow: found" || echo "glow: not found"
```
- `kubectl-sentinel`: proceed to Phase 1a if found; Phase 1b if not.
- `glow`: if found, write `/tmp/sentinel-report.md` and run `glow /tmp/sentinel-report.md` at report end.

---

## Phase 1a — Primary data source: kubectl-sentinel --json

```bash
kubectl-sentinel --json [--context <name>] [-n <namespace> if scoped]
```

- Exit codes 0, 1, 2 are all valid — do not treat non-zero as an error.
- `--json` is not valid for `pod/<name>` or `node/<name>` — skip to Phase 1b for those.
- If the command is not found: `bash install.sh ~/bin` from the kubectl-sentinel repo root, then retry.
- If the command returns non-JSON, fall through to Phase 1b.

When Phase 1a succeeds, skip Phase 1b and Phase 2 entirely. Go directly to Phase 3.

The script is the authoritative source for all severity thresholds. Do not override its CRITICAL/WARN/OK conclusions.

#### JSON schema (v1.0)

```json
{
  "schema_version": "1.0",
  "generated_at": "<ISO8601>",
  "context": "<context name>",
  "scope": "<all namespaces | namespace: X>",
  "exit_code": 0,
  "summary": { "critical": 0, "warn": 0, "ok": 0 },
  "sections": [
    {
      "section": "NODES | PODS | PROBES | WORKLOADS | HTTP | gRPC | EVENTS | RESOURCES | PVCS | HPAS",
      "findings": [
        {
          "severity": "CRITICAL | WARN | OK",
          "message": "<finding>",
          "recommendation": "<kubectl command or null>",
          "last_event": { "timestamp": "...", "reason": "...", "message": "..." }
        }
      ]
    }
  ]
}
```

**FailedMount findings** — the `message` field names the specific missing secret. Always surface it explicitly.

---

## Phase 1b — Fallback: K8s MCP (pod/node deep-dive, or script unavailable)

#### Cluster state

```
mcp__kubernetes__kubectl_get(resourceType="nodes", output="json")
mcp__kubernetes__kubectl_get(resourceType="pods", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="deployments", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="statefulsets", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="daemonsets", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="services", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="endpoints", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="persistentvolumeclaims", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="horizontalpodautoscalers", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="ingresses", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="events", allNamespaces=true, fieldSelector="type=Warning", sortBy="lastTimestamp", output="json")
mcp__kubernetes__kubectl_generic(command="top", resourceType="nodes")
mcp__kubernetes__kubectl_generic(command="top", resourceType="pods", flags={"all-namespaces": true})
```

#### Pod deep-dive

```
mcp__kubernetes__kubectl_get(resourceType="pod", name="<name>", namespace="<ns>", output="json")
mcp__kubernetes__kubectl_describe(resourceType="pod", name="<name>", namespace="<ns>")
mcp__kubernetes__kubectl_logs(resourceType="pod", name="<name>", namespace="<ns>", tail=50)
mcp__kubernetes__kubectl_logs(resourceType="pod", name="<name>", namespace="<ns>", tail=50, previous=true)
mcp__kubernetes__kubectl_generic(command="top", resourceType="pod", name="<name>", namespace="<ns>", args=["--containers"])
```

#### Node deep-dive

```
mcp__kubernetes__kubectl_get(resourceType="node", name="<name>", output="json")
mcp__kubernetes__kubectl_describe(resourceType="node", name="<name>")
mcp__kubernetes__kubectl_get(resourceType="pods", allNamespaces=true, fieldSelector="spec.nodeName=<name>", output="json")
mcp__kubernetes__kubectl_generic(command="top", resourceType="node", name="<name>")
```

---

## Phase 2 — Analysis rules (fallback only — skip if Phase 1a succeeded)

### Nodes
- Not `Ready` → CRITICAL; MemoryPressure / DiskPressure / PIDPressure → CRITICAL
- `KubeletRestart|KubeletCrash` condition `status=True` → CRITICAL
- Non-standard condition `status=True` → grouped WARN
- Cordoned → WARN; Version skew > 2 minor → WARN

### Pods
- `Failed` phase → CRITICAL; CrashLoopBackOff → CRITICAL (restart count, exit code)
- OOMKilled → CRITICAL (container name, memory limit); ImagePullBackOff → CRITICAL (image name)
- `CreateContainerConfigError` → CRITICAL (name the secret/configmap from events)
- Restart count > 50 → CRITICAL; > 10 → WARN; Pending → WARN (extract scheduler reason)

### Probes
- Liveness failures > 0 → CRITICAL; Readiness / startup failures → WARN

### Workloads
- `availableReplicas` == 0 (desired > 0) → CRITICAL; `availableReplicas` < `desiredReplicas` → WARN

### HTTP / gRPC
- No endpoints → CRITICAL; Not-ready endpoints → WARN; Ingress with no LB address → WARN

### Events
- Count > 50 → CRITICAL; > 10 → WARN
- `FailedMount`: name the specific missing secret explicitly

### Resources
- CPU/Memory ≥ 95% → CRITICAL; ≥ 85% → WARN

### PVCs
- `Pending` or `Lost` → CRITICAL; `Released` → WARN

### HPAs
- `minReplicas == maxReplicas` → WARN; `currentReplicas == maxReplicas` → WARN

### Root cause correlation
- FailedMount secret + ≥3 pods Pending → surface secret name directly
- ≥3 nodes Rebooted + ≥5 pods Pending → likely node pool upgrade
- Node NotReady + OOMKilling events → kubelet OOMKill cascade; parse `anon-rss` to find largest consumer

---

## Phase 3 — Report

### Analysis standards

- **Group by impact** — "entire payments stack is down — 5 deployments at 0 replicas, root cause: Secret `db-credentials` missing" not a list of each pod
- **Name the root cause** — when one secret/image/crash explains many failures, state it once
- **Assess blast radius** — for each CRITICAL, note user-visible impact
- **Surface correlated findings** — FailedGetResourceMetric + HPAs at ceiling → same problem
- **Cross-namespace blast radius** — OOMKill or NotReady may originate outside the scoped namespace; flag it
- **Do not pad** — if a section is clean, one OK row is enough

### Report format

```
══ SENTINEL CLUSTER REPORT ══
Context : <current-context>
Scope   : <all namespaces | namespace: X | pod: Y | node: Z>
Checked : <timestamp>
Source  : kubectl-sentinel --json | direct kubectl

┌─ STATUS: CRITICAL — <n> critical, <n> warning(s) ─────────────────────┐
  [CRITICAL] <first critical recommendation>
  ...

━━ ROOT CAUSE ANALYSIS ━━    ← only if a correlated pattern was found
  [PATTERN] / [LIKELY] / [ACTION]

━━ NODES ━━      ━━ PODS ━━      ━━ PROBES ━━     ━━ WORKLOADS ━━
━━ HTTP ━━       ━━ gRPC ━━      ━━ EVENTS ━━     ━━ RESOURCES ━━
━━ PVCS ━━       ━━ HPAS ━━

[All 10 sections always present. Each as a markdown table. OK sections → one row.]

━━ RECOMMENDATIONS ━━
| # | Severity | Recommendation |
|---|----------|----------------|
| 1 | CRITICAL | <action with concrete kubectl command> |

━━ SUMMARY ━━
| Severity | Count |
|----------|-------|
| CRITICAL | N     |
| WARN     | N     |
| OK       | N     |
```

### Report rules
- All 10 sections always present — one OK row if clean
- FailedMount: always name the secret, never just the count
- Recommendations: all CRITICALs; WARNs capped at 10
- No raw JSON or kubectl output — interpret and present
- No trailing summaries

---

## Phase 4 — Remediation (on user request)

**Rule: one write operation per confirmation.**

| Situation | Tool |
|-----------|------|
| Restart a deployment | `mcp__kubernetes__kubectl_rollout(subCommand="restart", resourceType="deployment", name, namespace)` |
| Roll back a deployment | `mcp__kubernetes__kubectl_rollout(subCommand="undo", resourceType="deployment", name, namespace)` |
| Scale replicas | `mcp__kubernetes__kubectl_scale(resourceType="deployment", name, namespace, replicas)` |
| Delete failed/evicted pods | `mcp__kubernetes__kubectl_generic(command="delete", resourceType="pods", namespace, flags={"field-selector": "status.phase=Failed"})` |

After executing: verify with `mcp__kubernetes__kubectl_rollout(subCommand="status", ...)` then `mcp__kubernetes__kubectl_get(resourceType="pods", namespace)`.

---

## Pod deep-dive (`pod/<name>`)

1. Phase, conditions, QoS class, node assignment
2. Per container: image, ready state, restart count, last exit code + reason
3. Probe configuration: type, path/command, initialDelaySeconds, periodSeconds, failureThreshold
4. Recent events — all types, last 20, newest first
5. Last 50 log lines — highlight ERROR / FATAL / panic / exception
6. Resource requests vs limits vs actual (kubectl top)

## Node deep-dive (`node/<name>`)

1. Conditions, kubelet version, OS, container runtime, roles
2. Capacity vs allocatable — CPU, memory, pods
3. Taints
4. Resource usage (note if unavailable)
5. Pods on node — group by namespace; show memory limit next to OOMKilled containers
6. OOM analysis: parse `anon-rss` from OOMKill events → rank by size → identify trigger process
7. Recent node events, last 15 — reconstruct timeline (OOMKills → kubelet restart → NodeNotReady)
