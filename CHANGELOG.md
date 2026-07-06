# Changelog

All notable changes to kubectl-sentinel are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/)

---

## [1.3.0] — 2026-07-06

### Added — stable check IDs
- Every finding now carries a **stable check id** (e.g. `POD-CRASHLOOP`, `PDB-BREACHED`, `POD-NO-CPU-REQUEST`) — a durable handle for a finding *type* that stays constant across runs even if the human-readable message is reworded. IDs make findings referenceable, greppable, suppressible, and correlatable over time, and give an AI/agent a typed key to reason over instead of parsing message text.
- **JSON**: each finding gains an `id` field (first key). `schema_version` bumped **1.0 → 1.1** (additive — existing consumers ignore the new field).
- **Text**: a new `Check` column sits between `Severity` and `Finding`. Deep-dive (`pod/`, `node/`) mode prints the id inline after the severity tag.
- **HTML**: a new `Check` column shows the id in monospace.

### Fixed
- Progress spinner now animates **only when stderr is an interactive terminal**. Previously, piping or redirecting output (e.g. `| tee`, `> log`, CI capture) flooded the stream with thousands of `\r`-based `Collecting cluster data…` lines. Non-interactive runs are now silent on stderr.

### Notes
- Purely additive; exit-code semantics unchanged. `incident-triage` ≥ 1.3.2 recognises `schema_version` 1.1; older versions still work (they emit a harmless schema-version notice).

---

## [1.2.1] — 2026-07-03

### Changed
- Relicensed to **Apache-2.0** (patent grant + attribution); added `NOTICE`, `TRADEMARKS.md`, and SPDX headers. Copyright standardized to Olawale Ogundiran.
- Docs are vendor-neutral: the reasoning layer is described as "any AI agent (via MCP or a reference skill)" rather than Claude-specific.

### Added
- **Krew** distribution: `.krew.yaml` plugin manifest and a tag-triggered release workflow — `kubectl krew install sentinel`.
- **Homebrew** formula template under `packaging/homebrew/`.
- `Documentation voice` standard in `CONTRIBUTING.md`.

_No behavioural change to the checks._

---

## [1.2.0] — 2026-07-03

### Added — five new deterministic checks (single-`kubectl` snapshot, no new dependencies)
- **JOBS** — failed Jobs (CRITICAL), Jobs retrying toward `backoffLimit` with no success (WARN), suspended CronJobs (WARN)
- **PDBS** — PodDisruptionBudget protection breached `currentHealthy < desiredHealthy` (CRITICAL); `disruptionsAllowed == 0` blocks node drains/upgrades (WARN)
- **QUOTAS** — ResourceQuota saturation for integer-valued resources (pods, object counts): ≥100% → new objects rejected (CRITICAL), ≥90% (WARN). CPU/memory quantities intentionally skipped to avoid unit-math false positives
- **DNS** — CoreDNS/kube-dns availability in `kube-system` (cluster-wide): 0 available → CRITICAL, degraded → WARN
- **CERTS** — cert-manager `Certificate` expiry from `.status.notAfter` (expired/≤7d CRITICAL, ≤21d WARN) and not-`Ready` (CRITICAL); gracefully skipped when the CRD is absent

### Added — extensions to existing sections
- **PODS** — flags containers with no CPU request (poor scheduling + lowest QoS/eviction priority) (WARN)
- **WORKLOADS** — flags Deployments whose rollout is not Progressing (e.g. `ProgressDeadlineExceeded`) while old replicas stay up (WARN)

### Notes
- JSON schema unchanged (`schema_version` 1.0) — only new section names appear. Exit-code semantics unchanged.

---

## [1.1.1] — 2026-07-02

### Fixed
- HTML report (`--output-format html`) now resolves the kubeconfig context through the same `--context`-aware wrapper as text and JSON output, instead of always reading the active context

### Added
- GitHub Actions CI: ShellCheck, `bash -n` syntax check, and a no-cluster smoke test (`--version`, `--help`) on every push and pull request

---

## [1.1.0] — 2026-04-11

### Added
- `--version` flag — prints `kubectl-sentinel 1.1.0` and exits
- `TOOL_VERSION` constant in script header

---

## [1.0.0] — 2026-04-11

Initial public release.

### Added

- 10-section cluster health checker: NODES, PODS, PROBES, WORKLOADS, HTTP, gRPC, EVENTS, RESOURCES, PVCS, HPAS
- Coloured text output ranked by severity (CRITICAL → WARN → OK)
- `--json` flag: structured JSON output (schema v1.0) for automation and CI pipelines
- HTML output: self-contained report with severity colour coding
- Exit codes: `0` all clear · `1` WARN findings · `2` CRITICAL findings (preserved in JSON mode)
- `-n <namespace>`: scope all checks to one namespace
- `--context <name>`: target a specific kubeconfig context without changing the active one
- `--verbose`: expand all grouped findings; remove WARN recommendation cap
- `--no-color`: plain text output for log ingestion
- `pod/<name>`: pod deep-dive mode with container detail
- `node/<name>`: node deep-dive mode with pod listing
- `install.sh`: installs to `~/bin` or a custom path
- stdlib only: requires `kubectl` and `jq` — no additional dependencies
