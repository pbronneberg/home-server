---
name: tdd
description: "Develop executable behavior through small red-to-green slices at accepted public test boundaries."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/tdd
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "codebase-design"
---

# Tdd

Read accepted behavior and test boundaries. Reuse approval and established
public interfaces; do not ask before every test. Material new boundaries return
to Specifier and applicable gate. Consult `codebase-design` for interface shape,
[tests.md](tests.md) for test quality and the test-sensitivity procedure when
hardening failure paths; use [mocking.md](mocking.md) for substitutes.

1. Pick one behavior and an independently established expected outcome.
2. Add the test and observe it fail for that behavior, not broken setup.
3. Implement only enough to pass; rerun it and relevant nearby checks.
4. As Coder, clean up while preserving behavior and rerun affected checks.
   Repeat one slice at a time; challenge meaningful failure paths before handoff.

Tests describe observable outcomes and survive internal refactors. Avoid private
method assertions, internal-call mocks, or expected results that recompute the
implementation. Do not write all speculative tests before learning from the first
slice. Meaningful failure cases and analyzer fixtures matter more than counts.
Use render/policy checks for declarative configuration; do not manufacture unit
tests for reversible prose changes.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
