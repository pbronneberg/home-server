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
- Do not duplicate full instruction blocks across `AGENTS.md`,
  `.github/copilot-instructions.md`, and `.github/instructions/`.
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
- Keep generated Helm dependency files and packaged charts out of git unless a
  user intentionally asks to vendor dependencies.
- Update `README.md` when setup, maintenance, or deployment commands change.

## Kubernetes And Helm

- Treat Helm charts as the primary source of application manifests.
- Run `make ci` before proposing or merging changes.
- Run `helm dependency build` before linting charts that declare
  dependencies.
- Render charts with `helm template` after changing templates or values.
- For secret-backed values, add safe placeholder keys to committed values and
  keep real values in ignored `*.secrets.yaml` files.
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

## Specialized Agent Guidance

- Read `.github/agents/home-platform.agent.md` for Kubernetes, Helm, storage,
  DNS, ingress, TLS, observability, and operational maintenance.
