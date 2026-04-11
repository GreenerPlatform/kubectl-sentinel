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

Do not proceed to Phase 1a/1b with expired credentials — kubectl-sentinel will appear to succeed but all findings will be authentication failures masquerading as WARN, not real cluster state.

**Step 4 — Tool availability.**
```bash
command -v kubectl-sentinel && echo "kubectl-sentinel: found" || echo "kubectl-sentinel: not found"
command -v glow && echo "glow: found" || echo "glow: not found"
```
- `kubectl-sentinel`: proceed to Phase 1a if found; Phase 1b if not.
- `glow`: if found, write `/tmp/sentinel-report.md` and run `glow /tmp/sentinel-report.md` at report end.
  If not found, surface in `── REPORT RENDERING ──`:
  ```
  NOTE: glow not installed — install for rich terminal rendering (colour tables, scrollable output):
    Ubuntu/Debian : sudo apt install glow
    macOS         : brew install glow
    Other         : https://github.com/charmbracelet/glow#installation
  ```

---

## Phase 1a — Primary data source: kubectl-sentinel --json

**This is the preferred path. It is a single command and requires only one permission prompt.**

```bash
kubectl-sentinel --json [--context <name>] [-n <namespace> if scoped]
```

- Exit codes 0, 1, 2 are all valid — do not treat non-zero as an error.
- `--json` is not valid for `pod/<name>` or `node/<name>` — skip to Phase 1b for those.
- If the command is not found (`command not found`): install it first — `bash install.sh ~/bin` from the kubectl-sentinel repo root, then retry.
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

**`last_event`** — when non-null, include the timestamp and message as a sub-row under the finding.

---

## Phase 1b — Fallback: K8s MCP (pod/node deep-dive, or script unavailable)

Use K8s MCP tools directly. No batching needed — each call is a structured tool invocation, not a shell prompt.

#### Cluster state

```
mcp__kubernetes__kubectl_get(resourceType="nodes", output="json")
mcp__kubernetes__kubectl_get(resourceType="pods", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="deployments", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="statefulsets", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="daemonsets", allNamespaces=true, output="json")
```

#### Services, storage, scaling

```
mcp__kubernetes__kubectl_get(resourceType="services", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="endpoints", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="persistentvolumeclaims", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="horizontalpodautoscalers", allNamespaces=true, output="json")
mcp__kubernetes__kubectl_get(resourceType="ingresses", allNamespaces=true, output="json")
```

Ignore errors for ingresses — CRD may not be installed.

#### Events and resource usage

```
mcp__kubernetes__kubectl_get(resourceType="events", allNamespaces=true, fieldSelector="type=Warning", sortBy="lastTimestamp", output="json")
mcp__kubernetes__kubectl_generic(command="top", resourceType="nodes")
mcp__kubernetes__kubectl_generic(command="top", resourceType="pods", flags={"all-namespaces": true})
```

If `kubectl_generic top` fails, note metrics-server unavailable in the RESOURCES section — do not stop.

#### Pod deep-dive

```
mcp__kubernetes__kubectl_get(resourceType="pod", name="<name>", namespace="<ns>", output="json")
mcp__kubernetes__kubectl_describe(resourceType="pod", name="<name>", namespace="<ns>")
mcp__kubernetes__kubectl_logs(resourceType="pod", name="<name>", namespace="<ns>", tail=50)
mcp__kubernetes__kubectl_logs(resourceType="pod", name="<name>", namespace="<ns>", tail=50, previous=true)
mcp__kubernetes__kubectl_generic(command="top", resourceType="pod", name="<name>", namespace="<ns>", args=["--containers"])
```

`kubectl_describe` includes events for the pod — use these for probe failures and scheduling reasons. `previous=true` logs may return empty if no prior container — ignore the error.

#### Node deep-dive

```
mcp__kubernetes__kubectl_get(resourceType="node", name="<name>", output="json")
mcp__kubernetes__kubectl_describe(resourceType="node", name="<name>")
mcp__kubernetes__kubectl_get(resourceType="pods", allNamespaces=true, fieldSelector="spec.nodeName=<name>", output="json")
mcp__kubernetes__kubectl_generic(command="top", resourceType="node", name="<name>")
```

`kubectl_describe` for a node covers conditions, capacity, taints, allocated resources, and node events — no separate events call needed.

---

## Phase 2 — Analysis (fallback only)

Apply these rules to the data from Phase 1b. Skip if Phase 1a produced valid JSON.

### 1. Nodes
- Not `Ready` → CRITICAL (include pod count on that node)
- MemoryPressure / DiskPressure / PIDPressure → CRITICAL
- Any condition with name matching `KubeletRestart|KubeletCrash` and `status=True` → CRITICAL
- Any non-standard condition (`status=True`, type not in Ready/MemoryPressure/DiskPressure/PIDPressure/NetworkUnavailable) → grouped WARN
- Cordoned / unschedulable → WARN (include running pod count)
- Version skew > 2 minor → WARN
- Node events: group by pattern — Rebooted/ContainerdStart only → single grouped WARN; CoreDNSUnreachable only → single grouped WARN; mixed/unusual → individual WARN per node

### 2. Pods
- Phase `Failed` → CRITICAL
- CrashLoopBackOff → CRITICAL (restart count, last exit code)
- OOMKilled → CRITICAL (container name, memory limit)
- ImagePullBackOff / ErrImagePull → CRITICAL (include image name)
- `CreateContainerConfigError` → CRITICAL (missing Secret or ConfigMap — name it from events)
- Restart count > 50 → CRITICAL (individual); > 10 → WARN
- Pending → WARN (extract scheduler reason; never leave blank)
- Container with no `resources.limits.memory` → WARN for non-system namespaces (group by owner); skip kube-system, gmp-system, istio-system, and similar infrastructure namespaces

### 3. Probes
- Liveness failures > 0 → CRITICAL
- Readiness / startup failures → WARN

### 4. Workloads
- `availableReplicas` == 0 (with desired > 0) → CRITICAL
- `availableReplicas` < `desiredReplicas` → WARN
- DaemonSet `numberUnavailable` > 0 → WARN

### 5. HTTP
- Service on HTTP port or `http`-named port with no endpoints → CRITICAL
- Endpoints exist but not ready → WARN
- Ingress with no LB address → WARN

### 6. gRPC
- Service with `grpc` port name or `appProtocol` with no endpoints → CRITICAL
- Not ready endpoints → WARN

### 7. Events
- Count > 50 → CRITICAL; > 10 → WARN
- `FailedMount`: extract the most-referenced missing secret name from event messages; name it explicitly
- `CreateContainerConfigError`: name the missing Secret or ConfigMap if visible in events

### 8. Resources
- CPU ≥ 95% → CRITICAL; ≥ 85% → WARN
- Memory ≥ 95% → CRITICAL; ≥ 85% → WARN
- Skip if metrics-server unavailable; note it in RESOURCES section

### 9. PVCs
- `Pending` or `Lost` → CRITICAL
- `Released` → WARN

### 10. HPAs
- `minReplicas == maxReplicas` → WARN (cannot autoscale)
- `currentReplicas == maxReplicas` → WARN (at ceiling)

### 11. Root cause correlation
After all checks, look for patterns and emit a ROOT CAUSE ANALYSIS block if found:
- **Node pool upgrade + pending pods:** ≥3 nodes with Rebooted events AND ≥5 pods Pending → likely upgrade in progress; if a FailedMount secret was also found, name it and give a 3-step action plan
- **Missing secret + pending pods:** FailedMount secret identified AND ≥3 pods Pending → surface the secret name directly
- **OOM cascade → kubelet death:** Node is NotReady AND has OOMKilling events → the kubelet itself was OOMKilled. Identify the single largest OOM event by parsing `anon-rss` from OOMKill event messages — that process is the root cause, not the downstream victims. Name it explicitly. Note whether the root cause is in a different namespace than the scope of the current check.

---

## Phase 3 — Analysis and report

### Analysis quality standards

**Group by impact, not by resource.** Rather than listing every failing pod individually, state the namespace-level impact: "entire payments stack is down — 5 deployments at 0 replicas, root cause: Secret `db-credentials` missing."

**Name the root cause explicitly.** When a missing Secret, wrong image tag, or crashed dependency explains multiple failures, state it once at the top of that namespace's finding.

**Distinguish stable vs unstable failures.** A pod with 67 restarts in CrashLoopBackOff is more urgent than one with 11.

**Assess blast radius.** For each CRITICAL, note the user-visible impact: service is down, autoscaling is blind, all jobs are failing.

**Surface correlated findings.** If FailedGetResourceMetric events are high AND multiple HPAs are at max ceiling, both are consequences of the same metric collection problem — say so.

**Cross-namespace blast radius.** When a namespace-scoped check shows nodes going NotReady or OOMKilling, the root cause may be a pod in a *different* namespace sharing the same node. Flag this explicitly.

**Do not pad.** If nodes are clean, say `[OK] All N nodes Ready — no pressure, no cordoned nodes, uniform v1.33.5, resource usage within limits.` One sentence. Do not enumerate every node.

### Report format

```
══ SENTINEL CLUSTER REPORT ══
Context : <current-context>
Scope   : <all namespaces | namespace: X | pod: Y | node: Z>
Checked : <timestamp>
Source  : kubectl-sentinel --json | direct kubectl

┌─ STATUS: CRITICAL — <n> critical, <n> warning(s) ─────────────────────┐
  [CRITICAL] <first critical recommendation>
  [CRITICAL] <second critical recommendation>
  ... (up to 5; "... and N more — see RECOMMENDATIONS")

━━ ROOT CAUSE ANALYSIS ━━    ← only if a correlated pattern was found
  [PATTERN] ...
  [LIKELY]  ...
  [ACTION]  1. ...
            2. ...
            3. ...
```

Followed by 10 sections, always in this order, always present:

```
━━ NODES ━━
| Severity | Resource | Finding |
|----------|----------|---------|
| CRITICAL | node/worker-1 | NOT Ready since 14:32 — 8 running pod(s) affected |
| WARN     | 6 nodes | rolling-restart events (Rebooted/ContainerdStart) — consistent with node pool upgrade |
| OK       | — | All 12 nodes healthy — no pressure, no cordoned, uniform v1.33.5 |

━━ PODS ━━
| Severity | Namespace | Finding |
|----------|-----------|---------|
| CRITICAL | payments (5 deployments) | 0 replicas available — Secret `db-credentials` missing; entire stack down |
| CRITICAL | staging/my-api | CrashLoopBackOff — 67 restarts (container: api, last exit: 1) |
| WARN     | backend (10 pods) | High restart count 11–26r (worker processes) |

━━ PROBES ━━
| Severity | Namespace | Finding |
|----------|-----------|---------|
| CRITICAL | payments (6 events) | Liveness probe failures — pods will be restarted |
| WARN     | istio-system (36 events) | Readiness probe failures — HTTP 503 — pods removed from service endpoints |
| OK       | — | No probe failures detected |

━━ WORKLOADS ━━
| Severity | Kind | Namespace/Name | Replicas |
|----------|------|----------------|----------|
| CRITICAL | Deployment | default/api-gateway | 0/1 available |
| WARN     | Deployment | staging/my-api | 2/3 available |

━━ HTTP ━━
| Severity | Namespace/Service | Port | Finding |
|----------|-------------------|------|---------|
| CRITICAL | payments/api-svc | 8080 | No endpoints — selector may not match pods |
| WARN     | frontend/web-svc | 80 | 2 endpoint(s) not ready |
| OK       | — | All HTTP services healthy |

━━ gRPC ━━
| Severity | Namespace/Service | Port | Finding |
|----------|-------------------|------|---------|
| OK       | — | No gRPC service issues |

━━ EVENTS ━━
| Count | Reason | Severity | Finding |
|-------|--------|----------|---------|
| 326 | FailedGetResourceMetric | WARN | HPAs cannot collect metrics — autoscaling decisions degraded |
| 239 | FailedMount | CRITICAL | Secret `db-credentials` missing — 51 occurrences in payments |
| 193 | Unhealthy | WARN | Readiness probe failures — HTTP 503 (43), 500 (18), 502 (8) |

━━ RESOURCES ━━
| Severity | Node | CPU | Memory |
|----------|------|-----|--------|
| CRITICAL | node-1 | 97% | 82% |
| WARN     | node-2 | 88% | 51% |
| OK       | — | All 12 nodes within thresholds — max CPU 32%, max memory 52% |

━━ PVCS ━━
| Severity | Namespace/PVC | Phase | Finding |
|----------|---------------|-------|---------|
| CRITICAL | data/postgres-pvc | Lost | — |
| OK       | — | All 18 PVCs Bound |

━━ HPAS ━━
| Severity | Namespace/HPA | Finding |
|----------|---------------|---------|
| WARN     | production/api-gateway-auto-scale | min == max (3) — cannot autoscale |
| WARN     | default/web-worker | at ceiling (6/6) |

━━ RECOMMENDATIONS ━━
| # | Severity | Recommendation |
|---|----------|----------------|
| 1 | CRITICAL | payments: create missing Secret `db-credentials` — `kubectl get secret db-credentials -n payments` then recreate from vault/pipeline and run `kubectl rollout restart deployment -n payments` |
| 2 | WARN | backend workers: check crash cause — `kubectl logs <pod> -n backend --previous` |

━━ SUMMARY ━━
| Severity | Count |
|----------|-------|
| CRITICAL | N     |
| WARN     | N     |
| OK       | N     |
```

### Report rules

- **All 10 sections always present** — never omit a section. If clean, one `OK` row is enough.
- **ERROR row** — if a check could not retrieve data (RBAC, timeout), show `ERROR | <resource> | Could not retrieve: <reason>`. Do not silently skip.
- **kubectl-sentinel JSON** — render findings exactly as returned. Do not re-derive severities.
- **Grouped findings** — one row per group, not one row per resource.
- **last_event** — show timestamp and truncated message as a sub-row or parenthetical when non-null.
- **FailedMount** — always name the secret, never just the count.
- **Recommendations** — all CRITICALs shown; WARNs capped at 10. Each recommendation includes a concrete kubectl command. Ordered CRITICAL → WARN.
- **No trailing summaries** — end at SUMMARY. No "in conclusion" paragraphs.
- **No raw JSON or kubectl output** — interpret and present; never paste verbatim.

After the SUMMARY table, always append:

```
── REPORT RENDERING ──
  This report is rendered as markdown in the terminal. Better viewing options:
  1. [TERMINAL]  Write /tmp/sentinel-report.md, then:
                 - If glow found: run `glow /tmp/sentinel-report.md`
                 - If glow not found: install for rich terminal rendering (see Phase 0)
  2. [HTML]      kubectl-sentinel --output-format html > /tmp/sentinel.html && xdg-open /tmp/sentinel.html
  Note: do not upload to third-party rendering tools — report contains internal node names,
        namespace topology, and secret names.
```

---

## Phase 4 — Remediation (on user request)

When the user asks to execute a fix ("do it", "run that", "yes fix it"), state the exact action first, wait for confirmation if not already given, then execute using K8s MCP write tools.

**Rule: one write operation per confirmation. Never chain writes without re-confirming.**

| Situation | Tool |
|-----------|------|
| Restart a deployment | `mcp__kubernetes__kubectl_rollout(subCommand="restart", resourceType="deployment", name, namespace)` |
| Roll back a deployment | `mcp__kubernetes__kubectl_rollout(subCommand="undo", resourceType="deployment", name, namespace)` |
| Scale replicas | `mcp__kubernetes__kubectl_scale(resourceType="deployment", name, namespace, replicas)` |
| Delete failed/evicted pods | `mcp__kubernetes__kubectl_generic(command="delete", resourceType="pods", namespace, flags={"field-selector": "status.phase=Failed"})` |

After executing: verify with `mcp__kubernetes__kubectl_rollout(subCommand="status", ...)` then `mcp__kubernetes__kubectl_get(resourceType="pods", namespace)`. Report in one line: "Rollout complete — 3/3 pods Running."

---

## Pod deep-dive mode (`pod/<name>`)

Present in this order:
1. Phase, conditions, QoS class, node assignment
2. Per container: image, ready state, restart count, last exit code + reason
3. Probe configuration: type (HTTP/TCP/exec/gRPC), path/command, initialDelaySeconds, periodSeconds, timeoutSeconds, failureThreshold
4. Recent events — all types, last 20, sorted newest first
5. Last 50 log lines per container — highlight lines containing ERROR / FATAL / panic / exception
6. Resource requests vs limits vs actual usage (from `kubectl top`)

## Node deep-dive mode (`node/<name>`)

Present in this order:
1. Conditions, kubelet version, OS image, container runtime, roles
   - Flag any condition matching `KubeletRestart|KubeletCrash` with `status=True` as CRITICAL inline
   - Flag any non-standard condition with `status=True` as WARN inline
2. Capacity vs allocatable — CPU, memory, pods
3. Taints
4. Resource usage (kubectl top — note if unavailable because node is unreachable)
5. Pods on node — namespace/name, phase, container restart counts + last exit code
   - Group by namespace; show memory limit next to each OOMKilled container if available
6. OOM analysis — if OOMKilling events are present:
   - Parse `anon-rss` values from all OOMKill event messages
   - Rank by anon-rss descending — the largest single consumer is the likely trigger
   - Note whether it has a memory limit set
   - Emit: "Largest OOM consumer: <process> in <namespace>/<pod> — <N> GB anon-rss, memory limit: <limit | none>"
7. Recent node events, last 15, all types sorted newest first
   - Reconstruct the timeline: when did OOMKills start, when did the kubelet first restart, when did NodeNotReady occur
