# AIHero skill sources and adaptations

These repository-local adaptations are derived from Matt Pocock's
[skills repository at the pinned revision](https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015).
Upstream revision: `3cca18b368ae95cdbdebbff572ccafa662551015`.
Upstream license: MIT, copyright 2026 Matt Pocock. Every adapted skill directory
includes the complete upstream license and source metadata in `SKILL.md`.
The platform review procedure and references are integrated into `code-review`
and retain their Apache-2.0 license and pbronneberg attribution separately from
the MIT-licensed AIHero adaptation.

The local coordinator distinguishes bounded shaping, large uncertain decision
maps, and focused standalone work. Shaping feeds a specification, while the local
Coordinator owns risk, stage independence, and acceptance. Wayfinder is reserved for uncertainty that
spans sessions, rather than required for every maintenance change.

| Local skill | Upstream location under `skills/` | Deliberate adaptation |
| --- | --- | --- |
| wayfinder | engineering/wayfinder | Keeps map, typed decision tickets, frontier, blockers, and human design decisions; hands to specification and uses the local GitHub tracker policy. |
| grilling | productivity/grilling | Small focused rounds; facts explored first; accepted decisions reused without ceremonial approval. |
| grill-with-docs | engineering/grill-with-docs | Combines interviewing and domain language; existing decision records replace a new parallel documentation tree. |
| domain-modeling | engineering/domain-modeling | Retains precise domain language and selective decisions; glossary/decision reference formats follow local conventions. |
| research | engineering/research | Primary-source citations retained; subagents optional by host capability and authorization; no automatic branches or commits. |
| prototype | engineering/prototype | Keeps runnable learning and logic/UI references; also permits fixture/render experiments; synthetic data and no automatic promotion or publication. |
| to-spec | engineering/to-spec | Proportional acceptance criteria replace extensive mandatory stories; Specifier reconciles operator value, independent QA expectations, and feasibility. |
| to-tickets | engineering/to-tickets | Independently verifiable slices and expand-contract retained; explicit dependencies and authorized publication or local drafts. |
| implement | engineering/implement | Coder owns implementation/refactoring/hardening and hands to Reviewer; removes automatic self-review and commit; honors accepted gates and test boundaries. |
| tdd | engineering/tdd | Small red-to-green slices with independent outcomes; references adapted to analyzers and configuration; reuses accepted test boundaries. |
| codebase-design | engineering/codebase-design | Cohesive modules, justified seams, and depth retained; alternative design work scales to risk and available agents. |
| code-review | engineering/code-review | One independent review keeps Standards and Spec distinct and includes all working-tree changes; platform guidance is a supporting reference; one six-section report covers all perspectives. |
| diagnosing-bugs | engineering/diagnosing-bugs | Symptom-specific reproduction and causal probes retained; portable human reproduction record replaces an interactive shell template. |
| handoff | productivity/handoff | Portable stage contract adds spec/candidate identity, observed checks, unproven claims, and next owner. |

## Reference files and portability

The local copies adapt upstream phase-boundary guidance, glossary and decision
formats, logic/UI prototype guidance, TDD test and mocking notes, and module
deepening and alternative-design references. Additional local references make
Wayfinder records, complete review scope, human reproduction, and stage handoffs
self-contained. These references intentionally use local examples and vocabulary.
No upstream executable debugging shell or host-specific runtime is required.

All dependency names resolve to local skills. Hosts may invoke a discovered skill
or explicitly read its `SKILL.md` and linked references. All included skills use
normal discovery. Unsupported host commands are not embedded in the workflow.

## Updating

Do not refresh automatically. Select and record an upstream revision, inspect the
upstream diff and license, then manually adapt changes against local instructions.
Review dependencies and reference links, preserve attribution, and run
`make ai-harness-check` plus applicable repository checks. Re-run behavioral
scenarios when routing, gates, review independence, or evidence rules change.
Structural checks establish document integrity, not model compliance.
