---
name: implement
description: "Implement an accepted specification or unblocked ticket and hand it to independent delivery stages."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/implement
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "tdd,codebase-design,handoff"
---

# Implement

Act as Coder within the Coordinator's pipeline. Read ticket, specification
revision, decisions, and gate record. Verify blockers are complete. Existing
explicit approval for the same scope satisfies the corresponding gate; do not
request it again. Return a missing required gate to the Coordinator before
dependent implementation.

Use `tdd` for executable behavior at agreed interfaces, one failing behavior then
the smallest passing implementation. For configuration use existing render,
schema, and policy checks. Prose edits need appropriate structural review rather
than mechanical unit tests. Keep changes cohesive and within scope, recording
criterion-to-check mapping. Do not weaken assertions or independent QA expectations
to make the candidate pass.

Coder also owns behavior-preserving cleanup using `codebase-design` and
meaningful failure-path coverage and test sensitivity using `tdd`. Start cleanup
from passing checks, preserve accepted expectations, and rerun affected checks.

Run relevant checks during development and required repository checks before
handoff. Record commands and observed results, including failures, skipped checks,
and missing tools. An unavailable live check cannot become a static pass.
Do not alter the spec to fit implementation; return drift to the Specifier.

Follow the Coordinator-selected stages. On the full delivery route, send a
`handoff` identifying candidate and remaining evidence to Reviewer. On the
routine route, complete applicable checks and hand off for the selected review;
do not dispatch full stages omitted with a recorded rationale. Self-review must
never substitute for independent review or be described as independent QA.
Do not automatically commit, publish, merge, deploy, or mark a human gate approved.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
