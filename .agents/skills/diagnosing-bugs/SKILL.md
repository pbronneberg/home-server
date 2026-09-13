---
name: diagnosing-bugs
description: "Establish a symptom-specific reproduction, test causal hypotheses, and verify a regression fix."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/diagnosing-bugs
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "tdd,codebase-design,handoff"
---

# Diagnosing Bugs

Coder owns fixes, regression tests, and temporary instrumentation. When using
this skill as Reviewer, remain read-only: inspect or run existing authorized
reproductions and return proposed tests, instrumentation, and repairs to Coder.
Do not modify the reviewed candidate or its expected outcomes.

Read relevant code and decisions to locate the symptom. Build one repeatable
command that detects the reported failure before claiming its cause: a public
interface test, CLI fixture, render comparison, or local replay. Make it fast
and deterministic; for intermittent failures record repetitions, seed, and actual
reproduction rate. Use synthetic or redacted evidence, never credentials or
private topology.

Observe failure and minimize inputs while preserving the actual symptom. If it
cannot run, report attempts, missing environment, and exact next check. Static
inspection can suggest hypotheses but cannot prove a fix. Live mutations retain
the existing authorization requirements.

Rank falsifiable hypotheses and their predictions. Probe one variable at a time;
performance claims need a baseline. Tag temporary instrumentation for targeted
cleanup. Use `tdd` to lock the minimized symptom at a suitable public boundary
before fixing it. If none exists, report the architectural issue with
`codebase-design`; do not substitute an insensitive test. Material new boundaries
or scope changes return to specification and applicable gate.

Rerun regression and original scenario, remove temporary instrumentation, and
record cause, evidence, and uncertainty. Coder sends the fix to Reviewer with
`handoff`; diagnosis does not bypass independent verification. For a human reproduction use
[HUMAN-REPRO.md](HUMAN-REPRO.md), not a custom interactive shell runtime.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
