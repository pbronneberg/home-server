---
name: grill-with-docs
description: "Clarify a plan while retaining resolved terminology and important decisions in existing repository documentation."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/grill-with-docs
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "grilling,domain-modeling,to-spec"
---

# Grill With Docs

Load `grilling` and `domain-modeling`; run focused interviews backed by code.
Keep working intent and unresolved questions with the GitHub work item or local
draft. Record stable terminology only when useful; accepted architectural
decisions belong in `docs/decisions/` using the existing convention.

Capture decisions and rationale as they settle, linking the source. Do not turn
a glossary into a competing specification or duplicate issue history. Reuse
accepted decisions and test boundaries. Hand sufficiently precise intent to
`to-spec`; do not prolong the interview to fill a template.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
