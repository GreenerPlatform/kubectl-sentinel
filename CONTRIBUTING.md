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

- **Every actionable finding has a next step** — it may gather evidence, validate a
  hypothesis, or propose remediation; it is not automatically a safe fix
- **Exit codes are a public API** — never change what an exit code means without bumping the major version; CI pipelines depend on them
- **Name the evidence** — "FailedMount: Secret `auth-tokens` missing" beats "mount error detected"
- **Classify before recommending** — OOMKill does not always mean "raise the limit"; the recommendation must follow the classification
- **Reproducible rules** — classifications should remain stable for equivalent captured
  inputs and tool versions; live collection is not an atomic snapshot

## Test

```bash
bash -n kubectl-sentinel
bash scripts/w5_proof_gate.sh
```

Fixture gates are necessary but not sufficient. Changes to collection status must execute
the CLI with successful, partial, failed, forbidden, and unavailable mocked collectors and
assert the generated section and coverage status. Live-cluster testing supplements fixture
tests; it does not replace them.

## Making changes

1. Fork the repo and create a branch: `git checkout -b fix/your-change`
2. Make your change
3. Run the offline gates, verify generated JSON, and add a regression fixture
4. When the change touches collection, validate it against a disposable cluster
5. Open a pull request with the section name and what you changed in the title

## Reporting bugs

Include:
- OS, shell version, bash version (`bash --version`)
- kubectl and jq versions
- The exact command you ran
- The smallest sanitized excerpt that reproduces the problem
- Cluster type (GKE, AKS, EKS, kind, etc.)

Do not post full reports or pod logs unless you have reviewed and redacted them. Remove
credentials, tokens, customer data, internal hostnames, and identifying metadata.

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
