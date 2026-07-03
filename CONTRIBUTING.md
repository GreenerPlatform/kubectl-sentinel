# Contributing

Issues and pull requests welcome.

## Getting started

```bash
git clone https://github.com/GreenerPlatform/kubectl-sentinel
cd kubectl-sentinel
bash install.sh ~/bin
kubectl sentinel -n default
```

## Design principles

- **Every finding carries its fix** — a finding without an actionable next command is incomplete
- **Exit codes are a public API** — never change what an exit code means without bumping the major version; CI pipelines depend on them
- **Name the evidence** — "FailedMount: Secret `auth-tokens` missing" beats "mount error detected"
- **Classify before recommending** — OOMKill does not always mean "raise the limit"; the recommendation must follow the classification
- **Deterministic** — same cluster state always produces the same output

## Smoke test

```bash
# Requires a live cluster
kubectl sentinel --json -n default | python3 -m json.tool
```

## Making changes

1. Fork the repo and create a branch: `git checkout -b fix/your-change`
2. Make your change
3. Test against a real cluster and verify JSON output is valid
4. Open a pull request with the section name and what you changed in the title

## Reporting bugs

Include:
- OS, shell version, bash version (`bash --version`)
- kubectl and jq versions
- The exact command you ran
- Full output with `--no-color` for clean text
- Cluster type (GKE, AKS, EKS, kind, etc.)

## Adding a new check

Each check section follows the same pattern:
1. Run `kubectl get` or `kubectl top` via a subprocess call
2. Parse the output with `jq` or awk
3. Emit findings via the `emit_finding` function with severity, message, and recommendation
4. Accumulate CRITICAL/WARN counts into the global summary

See an existing section (e.g. PODS or HPAS) as a reference implementation.

## Documentation voice

Docs represent production reliability engineering. Keep them firm and clean.

- Lead with the fact, not the feeling. State what it does and the number that proves it.
- Every claim is verifiable — a command, an exit code, a measurement — or it is cut.
- Second person, present tense, active voice. Short sentences.
- Do not use: leverage, robust, seamless, powerful, effortless, delve, game-changing,
  cutting-edge, supercharge, unlock, revolutionary, world-class, "in today's ...".
- No "it's not just X, it's Y" constructions. No emoji in prose.
