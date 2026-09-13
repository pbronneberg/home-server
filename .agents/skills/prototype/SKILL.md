---
name: prototype
description: "Build a disposable artifact to answer a specific design question before production implementation."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/prototype
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "handoff"
---

# Prototype

Name the question and observation needed to settle it. Pick the smallest useful
artifact: [LOGIC.md](LOGIC.md) for state and behavior, [UI.md](UI.md) for visual
alternatives, or a local fixture/render experiment for platform questions.
Clearly mark a scratch prototype and provide one run command or file. Use
synthetic public-safe data and in-memory state by default.

Skip production abstractions and polish; expose relevant state and awkward cases.
Record actual observations. Human preferences require the user's reaction;
a runnable demo is not design acceptance. Preserve question, artifact path,
command, verdict, and limitations in the work item or `handoff`.

Do not automatically commit, publish, provision, or modify live systems. Carry
validated decisions to specification; production code still needs normal delivery
checks. Clean up only artifacts created for this experiment within scope, never
unrelated user work.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
