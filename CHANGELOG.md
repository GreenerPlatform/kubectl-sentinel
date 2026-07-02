# Changelog

All notable changes to kubectl-sentinel are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/)

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
