# Semantic Review Rubric

During candidate review, apply this rubric after collecting available deterministic
evidence and recording unavailable checks. During specification planning, use
its questions to define the evidence that will be needed; execution is not yet
required. Do not turn conclusively decidable rules back into prompt-only checks.

## Severity

- **Critical**: credible path to secret disclosure, irreversible data loss, cluster or GitOps lockout, or authentication bypass.
- **High**: likely outage, unrecoverable migration, unsafe privileged operation, or major loss of operational control.
- **Medium**: meaningful maintainability, diagnosability, recovery, or deployment risk that should be corrected or consciously accepted.
- **Low**: bounded improvement with limited operational consequence.

## Architecture and complexity

- Does the solution match the home-lab use case, or add machinery without a proportionate operational benefit?
- Are boundaries, ownership, and dependencies understandable from the repository?
- Is the change additive and reversible where practical?

## Security and trust boundaries

- What assets and trust boundaries are affected, and which plausible threats does the change introduce or worsen?
- Which existing controls address those threats, and what evidence demonstrates their effectiveness?
- Assess credentials, permission scope, secret handling, network exposure, and recovery where relevant. Distinguish verified controls from assumptions and missing evidence.
- Report concrete risks with severity, supporting evidence, and an owning stage. Static checks alone do not establish security or compliance assurances.

## Migration and state

- For code-reported PVC, Secret, host, identity, or bootstrap changes, is there a credible migration and rollback plan?
- Are state ownership, ordering, interruption behavior, and recovery prerequisites explicit?
- Could individually safe changes combine into a data-loss or availability path?

## GitOps and recovery

- Does the desired-state change preserve bootstrap and recovery paths when in-cluster services are unavailable?
- Is reconciliation ordering appropriate, and can failure be diagnosed without hidden local state?
- Does the change weaken SOPS recovery, Flux authentication, storage recovery, or access to the Kubernetes API?

## Operations and observability

- Can an operator understand health, failure, and recovery without reconstructing implementation details?
- Are alerts, logs, metrics, runbooks, and manual gates proportionate to the operational risk?
- Are deployment and rollback steps credible rather than merely present?

## Evidence discipline

- Separate facts from inference.
- Do not repeat secret values.
- Do not claim checks passed without observed evidence.
- Explain why a deterministic warning is acceptable before approving it.

- Can a human assess an agent-authored change from its diff and verification output without reconstructing hidden reasoning or local state?
