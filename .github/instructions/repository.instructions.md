---
applyTo: "**"
---

# Repository-Wide AI Instructions

These instructions are shared by Codex, GitHub Copilot, and other AI coding
agents used in this repository.

## Repository Intent

This repository contains personal home-server Kubernetes and Helm
configuration. It favors boring, reviewable operations over clever automation.
Treat cluster state, secrets, storage, DNS, TLS, and networking as sensitive
surfaces.

## Instruction Ownership

- Keep reusable AI guidance in `.github/instructions/*.instructions.md`.
- Keep `AGENTS.md` as a thin entry point for Codex and other agents that read
  AGENTS files.
- Keep `.github/copilot-instructions.md` as a thin entry point for GitHub
  Copilot.
- Keep agent instructions in `.codex/agents/*.toml` and skills in `.agents/skills/`.
  `.github/agents/` contains thin Copilot entry points that load the Codex roles.
- Do not duplicate full instruction blocks across entry points or role adapters.
- When adding new guidance, put it in the narrowest applicable
  `.github/instructions/*.instructions.md` file.

## Operating Rules

- Prefer small pull requests with one operational intent.
- State deployment assumptions explicitly.
- Do not change live cluster behavior unless the user asked for that outcome.
- Preserve existing namespaces, hostnames, PVC names, and secret names unless
  there is a deliberate migration plan.
- Never commit real secrets, kubeconfigs, private keys, tokens, or local
  machine exports.
- Never commit real home-lab topology in plaintext. Use reserved example
  domains/IP ranges in public files and SOPS-encrypted overlays for private
  values.
- Keep generated Helm dependency files and packaged charts out of git unless a
  user intentionally asks to vendor dependencies.
- Update `README.md` when setup, maintenance, or deployment commands change.

## Kubernetes And Helm

- Treat Helm charts as the primary source of application manifests.
- Run `make ci` before proposing or merging changes.
- Run `make public-check` before changing repository visibility or touching
  files that could reveal private topology.
- Run `helm dependency build` before linting charts that declare
  dependencies.
- Render charts with `helm template` after changing templates or values.
- For secret-backed values, add safe placeholder keys to committed values and
  keep real values in ignored `*.secrets.yaml` files.
- For real operational values that must be versioned, use SOPS/age encrypted
  files under `private/*.sops.yaml`.
- For storage or network changes, call out possible data, DNS, ingress, or TLS
  impact in the PR description.

## GitHub Actions

- Use GitHub-hosted runners for repository maintenance workflows unless the
  user explicitly asks for self-hosted runner behavior.
- Keep workflow permissions minimal.
- Prefer pinned major versions for first-party setup actions and let
  Dependabot propose routine upgrades.
- Avoid workflows that deploy to the home cluster without an explicit manual
  gate and a documented rollback path.

## Domain Instructions and Specialist Agents

- For Kubernetes, Helm, Flux, storage, DNS, ingress, TLS, observability, and
  operational maintenance, read [home-platform.instructions.md](home-platform.instructions.md).
  These rules apply to every agent, including implementation and refactoring;
  do not wait until platform review to load them.
- For shared authentication and Grafana routing, also read
  [platform-auth.instructions.md](platform-auth.instructions.md). Follow this
  semantic routing even when the changed file falls outside an `applyTo` filter.
- Use domain skills for platform and security expertise within the current role.
  Agent files define the four distinct responsibilities: coordination,
  specification, implementation, and independent review. Skills provide task
  procedures; instructions own mandatory rules. Read a role when acting as it.

## Agent Delivery Workflow

For development work, follow `.github/instructions/agent-pipeline.instructions.md`.
It defines proportional routing, risk-based gates, and specialist handoffs.
Discover reusable skills under `.agents/skills/` and use
`docs/agents/issue-tracker.md` for work records. Run `make ai-harness-check`
when changing agents, skills, or harness guidance. Harness rules do not grant
permission to change live systems or publish to external services.
