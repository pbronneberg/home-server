---
name: domain-modeling
description: "Resolve ambiguous domain terminology and record meaningful architectural decisions while shaping work."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/domain-modeling
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
---

# Domain Modeling

Read existing documentation and decisions. Challenge overloaded words with
concrete scenarios and proposed canonical terms. Check behavioral claims against
code and distinguish current from intended behavior. Separate concepts with
different ownership or lifecycle.

Use [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md), reusing an existing glossary first;
create one only when needed. A glossary describes domain meaning, not plans or
implementation details. Record decisions only when hard to reverse, surprising
without context, and based on real alternatives. Follow
[ADR-FORMAT.md](ADR-FORMAT.md) and existing `docs/decisions/` conventions; do not
create a parallel ADR directory. Link working decision tickets as deliberation
sources rather than copying their entire discussion.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
