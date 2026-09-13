# Harness evaluation

Platform review was subsequently consolidated into `code-review` with one
six-section report; older skill counts and separate-artifact observations below
are historical, not the current review structure.

Ask Matt was subsequently removed at user request; its mentions below record
historical evaluations, not an available skill or current routing requirement.

## Unified review evaluation (2026-09-13)

An independent read-only reviewer found no remaining actionable issues in the
merge into `code-review`. It verified a single six-section report, unchanged
mandatory platform/auth routing, preserved MIT/Apache attribution, and no
references to the removed standalone skill. One conflicting prerequisite in the
moved rubric was corrected and reread: specification planning can use its
questions before executed evidence exists.

Two tabletop probes passed:

- Storage migration planning without a candidate defines recovery, cutover,
  rollback, and evidence requirements without requiring a diff or executed checks;
  it retains the planning packet and human Gate A.
- Candidate review with passing renders/CI but unavailable live recovery reuses
  current evidence in one report, records recovery as blocked/unproven with the
  next operator action, and retains human Gate B without granting live authority.

These observations test procedural consistency, not live recovery or native
client behavior. Author validation passed all 35 tests and `make ci`; the final
rubric also passed skill/reference validation after its wording correction.

## Codex-first packaging evaluation (2026-09-13)

An independent read-only reviewer assessed the uncommitted layout change against
HEAD `c69a22a` (scoped digest
`6a365820961aeb7e860a74cfada24aa6d37a16e311d50da9fb6c0f0a2f9b636c`).
It found no actionable issues: four canonical Codex TOML roles, thin Copilot
pointers, shared skills, preserved platform/auth routing, and no Claude files or
active references. Pipeline/skill validators and all 34 regression tests passed.
The author also observed `make ci` and `make public-check` passing with
`KUBECONFIG=/dev/null`; live cluster hints were explicitly skipped.

Validator fixtures exercise malformed TOML, missing roles and Copilot adapters,
wrong role pointers, broken references, and unresolved skill dependencies.
Live Codex/Copilot discovery was not exercised. These results establish packaging
and reference integrity, not model behavior, live-system readiness, or human gate
approval. The four-role behavioral assessment below still describes the delivery
contract; this change moved its source without adding stages.

## Four-role consolidation evaluation

An independent read-only reviewer assessed the consolidated roles, skills,
mandatory domain rules, documentation, and validator. It found no actionable
issues and observed 4 agents, 16 skills, and 29 regression tests passing.
The following are tabletop actions, not executed delivery or live verification:

| Scenario | Selected next action |
|---|---|
| Routine spelling correction | Brief criteria, Coder, applicable checks, independent Reviewer; record omitted stages/gates. |
| Risky auth change | Full specification and Gate A; retain auth invariants and require attributable affected-host evidence for live claims. |
| Coder refactors and adds negative tests | Stay in Coder's loop; preserve accepted boundaries, rerun affected checks, hand to Reviewer. |
| Reviewer finds a missing assertion | Return coverage gap to Coder, then review the correction and refreshed evidence. |
| Reviewer edits a test | The context becomes an author; require a fresh independent reviewer. |
| Host has no subagents | Prepare one portable Reviewer brief covering all relevant findings; disclose outstanding independence. |
| QA planning before implementation | Define expected outcomes without requiring a candidate or review base; final verification requires both. |

Platform/security assessment and acceptance verification are included in the
single Reviewer pass. Additional contexts require a concrete reason. This
assessment covers written routing and packaging, not runtime enforcement.

## Original evaluation (before role consolidation)

This section records the earlier multi-role harness; current routing is defined
in the shared pipeline instructions. On 2026-09-13, an independent agent read the repository entry point, pipeline and
tracker contracts, stage agents, and applicable curated skills. It performed a
read-only tabletop role-play of the ten requests below, reporting the next action,
route, gate disposition, and evidence limits. It did not execute those delivery
requests, access live environments, post to GitHub, or approve gates.

This is a behavioral interpretation of the written harness, not an end-to-end
runtime test or proof that a future model will obey it. Deterministic packaging
checks and executable regression fixtures are recorded separately below.

## Observed scenario responses

| Request or state | Evaluator's selected action and evidence boundary |
|---|---|
| Correct spelling without changing a runbook's meaning or commands | Routine path; inspect the diff and run applicable checks; no invented prose tests or operational gates. |
| Fix an analyzer missing plaintext Secret fixtures | Reproduce with synthetic fixtures and independent expected findings, then full delivery; security-control impact requires gates, reusing a matching existing approval. Local test success does not prove live security. |
| Plan a cluster migration with undecided storage and ingress | Wayfinder decision questions before specification and implementation tickets; unresolved preferences remain human decisions; unauthorized tracker updates remain drafts. |
| Rename a PVC and deploy with no migration packet | Prepare migration, rollback, and independent verification specification before Gate A. Existing deployment intent is retained, but it does not approve an unspecified migration. |
| Change an approved failure response during implementation | Return to Specifier, revise the affected criterion and QA expectation, and invalidate affected downstream evidence. Do not edit the old oracle to fit code. |
| Sign off restore readiness with renders but no live restore environment | Report static results and the blocked live criterion; provide the next restore probe and a not-ready recommendation. No fabricated restore evidence or agent-approved Gate B. |
| Request independent architecture and QA review on a host without subagents | Prepare separate portable briefs for fresh sessions; label any same-session review preliminary and independence outstanding. |
| Review when HEAD is unchanged but auth edits are staged and a script is untracked | Inspect the full candidate, retain tracked patch and untracked content identities, and recheck identity before final findings. A missing spec is unavailable, not passing. |
| Implement the same scope after explicit spec and test-boundary approval | Reuse the matching approval and proceed; only material drift reopens decisions. Final evidence acceptance remains distinct where required. |
| Invoke Ask Matt for advice only | Recommend a suitable entry path and stop; request the task description only if none is available. Do not dispatch stages or publish. |

## Findings and corrections

The evaluation identified three clarity gaps, corrected in the corresponding
instructions before final review:

- Coder and `implement` now follow the coordinator-selected next stage. Routine
  work does not accidentally dispatch the omitted full pipeline.
- Risk classification includes examples distinguishing spelling-only runbook
  edits from changes to a security analyzer, even with synthetic inputs.
- Coordinator uses Ask Matt only for explicit routing advice. Execution requests
  route through the shared contract directly.

The evaluator reread the corrections and repeated cases 1, 2, and 10. All three
findings were resolved, and it confirmed this summary reflects its observations.

A separate independent code review found two validator defects: valid YAML
indentation or a delimiter inside a scalar could bypass dependency checking, and
the canonical shared contract's references were not checked. Regression fixtures
were observed failing, then passing after corrections. Independent rereview
confirmed all four affected cases now report errors and found no remaining issue
in those fixes.

## Deterministic checks

- `make ai-harness-check`: validates the four current agent roles, sixteen skills
  (including the platform review), and the executable regression suite.
- `make ci`: includes harness validation, workflow/YAML lint, repository policy
  checks, Helm lint/render, Flux builds, and the report-only security audit.
- `make public-check`: includes CI plus working-tree/history secret scans and
  topology redaction checks.

For this implementation, the complete CI and publication targets passed with
network access to declared Helm repositories. Tools were installed in temporary
storage. Final repository-only checks used `KUBECONFIG=/dev/null`; live deployment
and restore claims are outside this harness change. The local Helm installation
emitted an existing incompatible helm-secrets plugin warning while continuing
successfully. No tool check was disabled to obtain a passing result.

The existing evidence collector retains its declared scope; a zero-finding report
does not attest to untracked files or the model's adherence to gates. Packaging
validation does not execute agents, and CI has no model API or cluster credentials.
