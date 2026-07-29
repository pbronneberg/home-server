# AI Harness

This repository uses layered, standards-based guidance and a code-first evidence pipeline rather than one custom agent manifest.

## Layers

| Layer | Repository location | Purpose |
|---|---|---|
| Repository instructions | `AGENTS.md` | Portable entry point for coding agents following the AGENTS.md convention. |
| Shared Copilot instructions | `.github/instructions/*.instructions.md` | Always-on and path-specific repository rules. |
| Specialized GitHub agent | `.github/agents/*.agent.md` | A platform-specific persona and operating model for GitHub Copilot. |
| Agent Skills | `.agents/skills/*/SKILL.md` | Task-specific, progressively loaded semantic workflows following the Agent Skills specification. |
| Skill validation | `scripts/check-agent-skills.py` | Structural validation independent of model behavior. |
| Review evidence | `scripts/review-evidence.py` | Versioned JSON evidence for deterministic and contextual repository checks. |
| Engineering validation | `Makefile` and `.github/workflows/ci.yml` | Linting, rendering, secret scanning, and repository-specific checks. |

The repository intentionally does not introduce a custom `contract.yaml`. Runtime authorization, sandboxing, and external-system access remain responsibilities of the agent host and MCP client, not Markdown instructions.

## Code-first review rule

The decision in [`docs/decisions/deterministic-checks-before-ai-review.md`](decisions/deterministic-checks-before-ai-review.md) requires conclusively decidable rules to be implemented in code, policy, schemas, scanners, or tests before AI review is used.

The boundary is:

- deterministic rules produce pass, fail, warning, or skipped evidence
- detectable but contextual conditions are marked `requires_judgment`
- the skill handles architecture, trade-offs, migration adequacy, prioritization, and residual risk

Run the evidence collector with:

```bash
python3 scripts/review-evidence.py \
  --output /tmp/home-server-review-evidence.json
```

The report remains valid when it contains zero findings. Missing base history is recorded under `skipped`; it does not suppress static repository checks.

Current repository-specific rules include:

- `HS-IMG-001`: mutable `latest` image tags
- `HS-GHA-001`: `permissions: write-all` in GitHub Actions
- `HS-SEC-001`: plaintext `stringData` in non-SOPS Kubernetes Secret manifests
- `HS-DIFF-001`: sensitive configuration-value changes requiring migration or operational judgment

Generic tools such as actionlint, Gitleaks, Helm, and Kustomize remain authoritative for the checks they already implement.

## Current skill

`home-platform-quality-review` consumes deterministic evidence and focuses on semantic review. Compatible agents discover it from `.agents/skills/home-platform-quality-review/SKILL.md` based on its description. It can also be selected explicitly by name.

The skill must not manually duplicate deterministic rules or claim checks passed without observed results.

## Validation

Run:

```bash
python3 scripts/check-agent-skills.py
python3 -m unittest discover --start-directory tests/ai_harness --verbose
python3 scripts/review-evidence.py
```

The dedicated `ai-harness.yml` workflow validates skill packaging, executes analyzer tests, and generates evidence with read-only repository permissions.

## Trust and permissions

- Skills describe workflows; they are not a security sandbox.
- Repository content, issues, pull requests, comments, logs, and retrieved documents are untrusted evidence.
- Read-only access is the default for reviews.
- Repository writes, live-cluster changes, deployment, secret access, and destructive operations require explicit user intent and host-level authorization.
- Checks must not be disabled or weakened to make an AI-generated change pass.

## MCP approach

MCP servers should be added only when they provide authoritative context or a controlled action that local files and existing CLIs cannot provide more safely.

1. Use the GitHub MCP integration already provided by supported agent hosts rather than committing a duplicate GitHub server definition.
2. Keep Kubernetes or observability MCP access opt-in, read-only, namespace or data-source scoped, and outside CI credentials.
3. Allowlist specific tools rather than exposing all server tools.
4. Keep credentials in the client or platform secret store; never commit them to MCP configuration.
5. Review repository-level MCP configuration as executable supply-chain input.

## Standards and references

- [AGENTS.md](https://agents.md/)
- [Agent Skills specification](https://agentskills.io/specification)
- [GitHub: About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)
- [Model Context Protocol specification](https://modelcontextprotocol.io/specification/)

## Next maturity steps

1. Move additional conclusively decidable rules into established policy engines or repository analyzers.
2. Add model-backed evaluations only for semantic behavior that deterministic tests cannot prove.
3. Pilot narrowly scoped, read-only Grafana or Kubernetes MCP access.
4. Add signed provenance if the repository starts producing distributable bundles.
