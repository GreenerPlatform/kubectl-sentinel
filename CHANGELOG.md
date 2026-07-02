# Changelog

All notable changes to kubectl-sentinel are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/)

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
