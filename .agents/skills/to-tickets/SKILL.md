---
name: to-tickets
description: "Split an accepted specification into independently verifiable implementation slices with explicit blockers."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-tickets
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "handoff"
---

# To Tickets

Read the accepted specification revision, linked decisions, and relevant code.
Make small vertical slices with observable outcomes and independent evidence;
avoid tickets that merely finish one technical layer. A behavior-preserving
prerequisite refactor may itself be a verifiable slice.

Each ticket records parent spec/revision, outcome, acceptance criteria, test
boundaries, dependencies, environment assumptions, and applicable risk/gates.
Link decision rationale. Include only real blockers; independent slices need not
form a linear chain.

Wide migrations use expand → compatible migration batches → contract, with green
checks for every independently landable step. If an integration branch is needed,
identify non-landable steps and require a final integrate-and-verify ticket.

Present the breakdown and reuse approved granularity and dependencies; material
scope changes return to specification. Follow tracker policy for native
sub-issues/blockers or linked fallback dependencies. Publish only within
authorization, otherwise draft one file per ticket in dependency order. Do not
automatically close the parent. The Coordinator starts an unblocked ticket with
a bounded handoff.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
