---
name: grilling
description: "Clarify and stress-test unresolved intent through focused question rounds grounded in repository facts."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/grilling
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
---

# Grilling

Map decisions and their prerequisites. Inspect repository facts first; questions
for the user concern intent, preferences, and consequential tradeoffs. A missing
fact is an exploration task, not something to make the user look up.

Ask a small round of independent questions whose prerequisites are settled.
Give concrete options and a recommendation. Use a supported host question tool
or ordinary conversation. Wait for human answers to consequential design choices;
never invent their response. Explore independent facts while waiting when useful.
Questions dependent on an unresolved answer belong in a later round.

Recompute the frontier after each answer. Distinguish current behavior from
intended behavior when code contradicts the discussion. Finish with settled
decisions, explicit assumptions, and remaining unknowns. Reuse accepted answers;
do not restart an interview or require ceremonial confirmation. Material missing
scope or acceptance criteria return to the Specifier and applicable gate.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
