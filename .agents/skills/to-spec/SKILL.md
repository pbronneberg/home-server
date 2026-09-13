---
name: to-spec
description: "Synthesize established intent and evidence into a proportional specification for the delivery pipeline."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-spec
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "handoff"
---

# To Spec

Synthesize conversation, code, and linked Wayfinder resolutions without restarting
the interview. Return contradictions or consequential missing decisions to the
Specifier; an unresolved draft is not implementation-ready.

Include what makes the change buildable and verifiable:

- Problem, operator value, intended outcome, and scope exclusions.
- Observable numbered acceptance criteria with independent expected outcomes.
- Agreed interface and behavior changes, constraints, and linked decisions.
- Independent QA procedure: named system under test, governed synthetic inputs,
  setup, probes, expected observations, and criterion-to-check mapping.
- Test boundaries, checks, environment assumptions, and unavailable evidence.
- Migration, rollback, and recovery requirements when applicable.
- Specification revision and decision sources.

The Specifier reconciles operator value, Reviewer's independent QA expectations,
and developer feasibility before Gate A. Reuse accepted test boundaries; reopen only
material changes. Scale detail to risk instead of generating mandatory extensive
story lists. Exact paths or small contract snippets are useful when they prevent
ambiguity, not as speculative implementation prescriptions.

Publish only within authorization or prepare a local draft under tracker policy.
Readiness labels do not satisfy Gate A. Hand the identified spec revision to the
Coordinator, using `handoff` across sessions.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
