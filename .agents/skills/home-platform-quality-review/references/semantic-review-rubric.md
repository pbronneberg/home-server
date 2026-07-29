# Semantic Review Rubric

Use this rubric only after deterministic evidence has been collected. Do not turn conclusively decidable rules back into prompt-only checks.

## Severity

- **Critical**: credible path to secret disclosure, irreversible data loss, cluster or GitOps lockout, or authentication bypass.
- **High**: likely outage, unrecoverable migration, unsafe privileged operation, or major loss of operational control.
- **Medium**: meaningful maintainability, diagnosability, recovery, or deployment risk that should be corrected or consciously accepted.
- **Low**: bounded improvement with limited operational consequence.

## Architecture and complexity

- Does the solution match the home-lab use case, or add machinery without a proportionate operational benefit?
- Are boundaries, ownership, and dependencies understandable from the repository?
- Is the change additive and reversible where practical?

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
