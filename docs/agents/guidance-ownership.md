# Guidance ownership

The harness has four roles. Create another context only for a concrete scope or
independence need, rather than repeating the same review under a new persona.
Mandatory rules live in shared/domain instructions and apply to all roles;
reusable procedures live in skills. Canonical role instructions live in `.codex/agents/`;
`.github/agents/` contains only Copilot pointers, not extra roles.
See [Codex-first layout](../ai-harness.md#codex-first-layout) for discovery and maintenance.

| Role | Responsibility | Boundary |
|---|---|---|
| PipelineCoordinator | Routing, existing human gates, work records, evidence validity | Coordinates; does not implement or self-approve acceptance. |
| Specifier | Operator value, scope, behavioral contract, acceptance criteria | Owns intent; consults Reviewer for independent expectations and Coder for feasibility. |
| Coder | Implementation, behavior-preserving refactoring, test sensitivity, corrections | Changes the candidate; does not independently approve its own work. |
| Reviewer | Standards, specification, architecture, security/platform judgment, and acceptance verification | Read-only candidate review; all repairs return to Coder and intent gaps to Specifier. |

## Consolidated responsibilities

- ProductManager merged into Specifier: operator perspective and clear acceptance
  examples are part of specification, supported by grilling and domain modeling.
- Refactorer and Hardener merged into Coder: `codebase-design` and TDD retain
  tested cleanup and meaningful negative controls. Reviewer challenges evidence
  quality independently and requests corrections without writing them itself.
- Architect and QA merged into Reviewer: design judgment and verification of the
  accepted procedure belong to one independent assessment. Standards, Spec, and
  operational findings remain distinguishable; none can mask a failure in another.
- HomePlatform and SecurityArchitect removed as personas: mandatory platform/auth
  instructions and the platform reference in `code-review` retain operational invariants,
  asset/trust-boundary/threat/control analysis, security, recovery, and evidence
  discipline. A specialist agent is not needed to load these rules.

The full route is Specifier → Gate A → Coder → Reviewer → Gate B, managed by
Coordinator. Routine changes retain brief criteria, implementation/checks, and
independent review; large uncertain work still enters through Wayfinder. Human
gates remain risk-based and reuse matching existing approval.

## Preserved platform rules

Repository instructions route every relevant task to
`.github/instructions/home-platform.instructions.md` and, for shared auth/Grafana,
`.github/instructions/platform-auth.instructions.md`. Subject routing covers
indirect changes outside path filters. The review skill reads these files directly.
Live-pilot checks, OAuth2/Traefik and Grafana invariants, resource identities,
upgrade order, GitOps, recovery, privacy, and publication rules remain there.
The existing deterministic checks remain authoritative for the rules they cover.

## Review and maintenance

One Reviewer pass covers a candidate in one six-section report, with standards,
specification, and operational findings kept distinguishable. Additional reviewer contexts require a justified scope split,
unresolved risk, or independence need. A reviewer who changes the candidate
becomes an author and needs a fresh independent review. Corrections invalidate
affected evidence; unrelated, attributable results remain reusable.

The validator requires the four registered roles and domain instruction files,
checks shared links and skill dependencies, and rejects unregistered agent files
so obsolete personas cannot silently remain discoverable. Adding a new role
requires a deliberate registry change and a distinct responsibility.
See [evaluation records](harness-evaluation.md) for semantic assessment; structural
checks do not prove model behavior or runtime enforcement.
