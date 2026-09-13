---
name: research
description: "Investigate a bounded question against primary sources and capture cited findings and uncertainty."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/research
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "handoff"
---

# Research

State the question and what evidence would settle it. Investigate primary
sources: repository code, official documentation, specifications, and first-party
APIs. Follow material claims to the source that owns them. Include version or
access date for changeable facts, and distinguish observation from inference.

Use a bounded research subagent when supported and allowed; otherwise work in
this session. Record question, cited findings, source revisions, uncertainties,
and decision implications in existing research-note conventions or a work-item
draft. Do not automatically branch or commit. Research feeds human decisions,
not substitutes for them. Use `handoff` across sessions. Missing access remains
an evidence gap; never report inaccessible sources as verified.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
