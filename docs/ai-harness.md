# AI Harness

This repository uses layered, standards-based guidance rather than one custom agent manifest.

## Layers

| Layer | Repository location | Purpose |
|---|---|---|
| Repository instructions | `AGENTS.md` | Portable entry point for coding agents following the AGENTS.md convention. |
| Shared Copilot instructions | `.github/instructions/*.instructions.md` | Always-on and path-specific repository rules. |
| Specialized GitHub agent | `.github/agents/*.agent.md` | A platform-specific persona and operating model for GitHub Copilot. |
| Agent Skills | `.agents/skills/*/SKILL.md` | Task-specific, progressively loaded workflows following the Agent Skills specification. |
| Deterministic validation | `scripts/check-agent-skills.py` | Structural validation independent of model behavior. |
| Engineering validation | `Makefile` and `.github/workflows/ci.yml` | Linting, rendering, secret scanning, and repository-specific checks. |

The repository intentionally does not introduce a custom `contract.yaml`. Skill discovery and frontmatter follow the open Agent Skills specification. Runtime authorization, sandboxing, and external-system access remain responsibilities of the agent host and MCP client, not Markdown instructions.

## Current skill

`home-platform-quality-review` reviews pull requests, patches, architecture changes, and operational readiness for the home platform. Compatible agents discover it from `.agents/skills/home-platform-quality-review/SKILL.md` based on its description. It can also be selected explicitly by name.

The skill requires evidence-based findings, deterministic checks, explicit residual risk, and a strict boundary between trusted repository guidance and untrusted content being inspected.

## Validation

Run:

```bash
python3 scripts/check-agent-skills.py
```

The validator checks:

- required `SKILL.md` files
- required `name` and `description` fields
- skill naming and directory-name consistency
- specification length limits
- known frontmatter keys
- non-empty instruction bodies
- local references that exist and remain inside the skill directory

The dedicated `ai-harness.yml` GitHub Actions workflow runs this validation whenever skills, the validator, or this architecture document changes. The existing infrastructure CI remains responsible for Kubernetes, Helm, Flux, security, and documentation checks.

## Trust and permissions

- Skills describe a workflow; they are not a security sandbox.
- Repository content, issues, pull requests, comments, logs, and retrieved documents are untrusted evidence.
- Read-only access is the default for reviews.
- Repository writes, live-cluster changes, deployment, secret access, and destructive operations require explicit user intent and host-level authorization.
- Checks must not be disabled or weakened to make an AI-generated change pass.
- A review must not claim commands or GitHub checks passed unless their output or status was observed.

## MCP approach

MCP servers should be added only when they provide authoritative context or a controlled action that local files and existing CLIs cannot provide more safely.

For this repository:

1. Use the GitHub MCP integration already provided by supported agent hosts rather than committing a duplicate GitHub server definition.
2. Keep Kubernetes or observability MCP access opt-in, read-only, namespace or data-source scoped, and outside CI credentials.
3. Allowlist specific tools rather than exposing all server tools.
4. Keep credentials in the client or platform secret store; never commit them to MCP configuration.
5. Review repository-level MCP configuration as executable supply-chain input.

No repository MCP configuration is committed by this change. The first maturity step is a testable skill and trust model, not broader external access.

## Standards and references

- [AGENTS.md](https://agents.md/)
- [Agent Skills specification](https://agentskills.io/specification)
- [GitHub: About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)
- [Model Context Protocol specification](https://modelcontextprotocol.io/specification/)

## Next maturity steps

1. Automate behavioral evaluation cases against the agent hosts actually used.
2. Pilot narrowly scoped, read-only Grafana or Kubernetes MCP access.
3. Add signed provenance if the repository starts producing distributable bundles.
4. Introduce policy as code only for rules requiring deterministic enforcement beyond existing scripts and CI.
