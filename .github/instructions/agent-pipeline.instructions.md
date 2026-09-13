---
applyTo: ".github/agents/**,.codex/**,.agents/**,AGENTS.md,docs/ai-harness.md"
---

# Interactive Agent Pipeline

Read this contract whenever coordinating or performing a delivery stage. Follow
[repository instructions](repository.instructions.md) and the applicable
[platform rules](home-platform.instructions.md), including their auth-specific
routing. Load mandatory domain rules before specification or implementation,
regardless of the selected role. These are session instructions, not a
runtime, deployment permission, or proof of enforcement.

## Routing and risk

The coordinator selects and records one path:

- Routine maintenance: brief scope and observable acceptance criteria, implement,
  applicable checks, review. Record why omitted stages are unnecessary.
- Bounded behavioral change: clarify unresolved intent, specify, then run the
  delivery stages below.
- Large or uncertain effort: use `skill:wayfinder` for a decision map, resolve
  questions with the human, specify, then use `skill:to-tickets` for independently
  verifiable delivery tickets. Decision tickets remain distinct from delivery
  tickets; a decision map is not an implementation backlog.

The full sequence is Specifier → Gate A → Coder → Reviewer → Gate B.
Coordinator manages the run; it is not an additional delivery stage. Gates are
required for storage, recovery, authentication,
secrets, networking, deployment, architectural boundaries, and uncertain risk
classification. For other bounded changes, record why human gates are not
required; retain specification and independent verification stages. Reclassify
when discoveries increase risk. The coordinator owns routing and chooses
applicable local skills and platform review.

Classify the behavior being changed, not topic words in the touched document.
A spelling correction in a storage runbook that preserves commands and meaning
is routine. A fix to a synthetic-fixture analyzer that detects plaintext Secrets
changes a security control: use the full gated route even without live access.
For other analyzer changes, assess their actual operational/security effect;
test-first development alone does not imply a human gate.

## Gate contract

Gate A records human acceptance of the specification revision: scope, observable
acceptance criteria, test boundaries, environment assumptions, and rollback
requirements. Prepare the complete, reviewable specification before requesting
its acceptance. Gate B records human acceptance of attributable QA evidence
against that specification and candidate identity, including residual risks.
An agent cannot self-approve either human gate. When a gate is required and no
matching acceptance exists, pause dependent work and present the concrete packet.

Existing explicit human approval satisfies its corresponding gate for the same
scope and revision. Do not request it again. Material scope, contract, test-boundary,
or environment changes reopen affected decisions and Gate A; candidate changes
invalidate affected evidence and Gate B acceptance. Re-run affected downstream
stages before acceptance. Repository acceptance never authorizes live operations;
apply the repository's existing live-operation authorization requirements.

## Stage isolation and correction

Use separate agents with bounded handoffs when the host supports them and the
session permits delegation. Otherwise provide the same portable packet for a
fresh session. If a single context performs multiple stages, state that independent
verification remains outstanding; do not claim a fresh or independent review.
The coordinator routes and records work without implementing specialist stages.

Before Gate A, Specifier owns operator value and scope, with Reviewer supplying
independent expected outcomes and Coder checking feasibility. Use domain skills
and mandatory instructions for platform, security, and architecture constraints;
these are responsibilities within the four roles, not separate personas.

Coder owns implementation, behavior-preserving refactoring, and test hardening.
Reviewer independently assesses standards, specification, architecture, security,
and operational evidence, and executes the accepted verification procedure.
Keep these findings distinguishable within one review. Extra reviewer contexts
are warranted only for a concrete scope split, unresolved risk, or independence
need; do not schedule multiple equivalent reviews of the same candidate.

Route unclear intent and changed requirements to Specifier. Route all candidate
changes, including structural fixes and stronger tests, to Coder. Reviewer reports
findings without changing the candidate or its acceptance oracle. If a reviewer
changes code or tests, that context becomes an author and a fresh independent
review is required. After corrections, review the affected changes and rerun
checks whose evidence was invalidated; reuse unrelated, current evidence.

## Durable records and handoffs

GitHub issues and PRs hold working decision maps, delivery tickets, and handoffs.
Use native sub-issues and blocking relationships where available, otherwise
explicit parent and dependency links. Publish only when available and authorized;
otherwise prepare a local draft and label it unpublished. Accepted architectural
decisions belong in the existing `docs/decisions/` documentation. Do not create a
competing tracked status database or custom runtime authorization manifest.

Each stage emits this bounded packet, using `skill:handoff`:

```text
Work item: issue/PR link or unpublished draft location
Completed stage and executor/context:
Specification revision and acceptance-criterion IDs:
Candidate: commit SHA plus staged/unstaged diff and untracked-file identity
Artifacts changed:
Criteria covered and scenario/check mapping:
Evidence: commands, observed results, environment, artifact/report references
Findings: standards / specification mismatch / operational judgment
Blockers and claims not established:
Gate disposition: required/not required, rationale, human acceptance reference
Next stage and required inputs:
```

A commit SHA alone does not identify an uncommitted candidate. Record a content
digest or retained patch for staged and unstaged changes and content identities
for in-scope untracked files; never include secret contents in public artifacts.
Review the complete candidate, including uncommitted changes. Give each updated
specification a stable revision; link the human's actual acceptance instead of
inferring it from silence. Preserve failed and blocked check results, not just
successful reruns. An unavailable environment blocks its associated claim.

## Engineering and evidence

Use test-first behavioral slices for executable behavior and analyzers. Prefer
clear names, cohesive responsibilities, justified dependency boundaries, and
behavior-preserving refactoring. Use Helm renders, Kustomize builds, and existing
policy checks for configuration; do not invent unit tests for prose. Run existing
applicable checks and `make ci`; run `make public-check` for imported/public
material. Reuse accepted test boundaries rather than asking for repeated approval.

Deterministic tools provide standards evidence. Use
`skill:code-review` and its platform reference for applicable operational
judgment within the single six-section report; attach pipeline traceability. Do not
turn tool output into duplicate manual findings. Reviewer derives expected outcomes from
the specification, independently of implementation, and distinguishes static/render
results from live-system evidence. A successful render does not prove deployment,
recovery, authentication, or service behavior. No stage fabricates execution.
Before completion, review operator documentation and agent guidance for drift.
