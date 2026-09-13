---
applyTo: "application/**,clusters/**,private/**,scripts/**,.github/workflows/**,docs/**,Makefile"
---

# Home Platform Instructions

Apply these rules to Kubernetes, Helm, Flux, storage, DNS, ingress, TLS,
observability, deployment, recovery, and operational maintenance. They apply
regardless of agent selection, including implementation and refactoring. Follow the
[repository instructions](repository.instructions.md) for shared validation,
secret/topology handling, workflow permissions, and publication rules. Selecting
a review skill is not a prerequisite for these rules.

For shared authentication or Grafana routing work, also read
[platform-auth.instructions.md](platform-auth.instructions.md), including when
changing a values layer, ingress, dependency, or script outside its path filter
that can affect those flows.

## Desired state and operational boundaries

- Treat Git as the home lab's desired-state record: declarative, versioned,
  pulled by automation where appropriate, and checked for drift before live
  changes.
- Identify affected workloads, namespaces, hosts, services, and storage resources.
  Keep ingress, TLS, DNS, storage, and namespace changes explicit. Preserve data
  safety for PVCs, databases, object storage, and monitoring components.
- Prefer additive, reversible changes over destructive replacements. Preserve
  Service names along with the resource identities protected by repository rules
  unless there is a deliberate migration plan.
- Keep repository validation on GitHub-hosted public runners. Do not give those
  workflows cluster credentials; prefer manual deployment or a pull-based GitOps
  controller inside the cluster. Cluster deployment automation needs an explicit
  manual approval step and a documented rollback path.
- Use short-lived credentials such as OIDC if cloud/provider access is introduced,
  and keep dependency tooling responsible for routine workflow-action updates.
- For workload secrets, use ignored local values, SOPS-encrypted GitOps inputs, or
  an external secrets operator as appropriate; never plaintext Secrets in Git.
  Treat kubeconfigs, passwords, tokens, and local exports as private material.
- Before deployment, use the repository's workflow/YAML linting, Helm dependency
  build/lint/render, and Kustomize checks. Add schema/policy checks before enabling
  automated reconciliation.
- Keep K3s upgrades deliberate: upgrade control-plane/server nodes before agents,
  avoid skipping unsupported Kubernetes minor versions, and document rollback or
  uncordon steps.
- Introduce policy-as-code in audit mode first so reports can be assessed before
  enforcement risks downtime.
- Update operator documentation when commands or assumptions change. Before
  publication, run `make public-check` and follow `docs/publication-runbook.md`.

## Live pilot requirements

- For disposable infrastructure pilots, do not rely on runbook prose alone for
  behaviors that can only be proven against a live workload. Add executable
  harness checks when the work depends on SSH access, service readiness,
  cluster joins, API health, storage attachment, or reconciliation side effects.
- Make harness checks fail fast and non-interactively. For SSH, use batch mode
  or equivalent so missing key trust fails as an error instead of prompting for
  a password. For services, verify both the system service and the user-visible
  API or health endpoint.
- Wire new live harness checks into `make` targets and the relevant runbook.
  Run the non-mutating checks when the live cluster state allows it; if a check
  cannot be run safely, state the exact reason and the command the operator
  should run next.
- When a disposable pilot fails a live harness check, prefer fixing GitOps input
  and recreating the disposable resource over in-place repair, unless the user
  explicitly asks for recovery commands.
