---
name: handoff
description: "Create a portable stage handoff preserving specification identity, observed evidence, and unresolved work."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/handoff
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
---

# Handoff

Write a concise document using [TEMPLATE.md](TEMPLATE.md). Link authoritative
issues, specifications, decisions, commits, diffs, and evidence instead of
copying their histories. Include local draft content if the receiver cannot
access the source; never assume another machine can read a local path.

Default to an OS temporary file for portable session handoffs unless the work
item's local draft or authorized GitHub record is the intended destination.
Report the actual path. Redact secrets, personal information, and private topology.
Name suggested local skills and agent entry points; use available invocation or
explicit file reading, never assume proprietary slash commands or context APIs.

A handoff is evidence, not new authority. Preserve missing human approval and
outstanding independent verification. The receiver checks candidate identity
before reusing results and reruns affected checks after edits.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
