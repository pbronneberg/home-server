---
name: codebase-design
description: "Design cohesive modules and justified interfaces that hide complexity and remain easy to verify."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/codebase-design
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
---

# Codebase Design

A module groups cohesive behavior; its interface is everything callers must know.
Depth means useful behavior behind a small interface; a seam locates that
interface; an adapter satisfies it. Leverage is capability gained by callers;
locality is where changes, knowledge, and verification concentrate. Depth is not
a ratio of implementation lines to interface lines.

Prefer clear domain names, cohesive responsibility, explicit dependencies, and
observable results. Hide decisions that change together. Internal collaborators
need not become public just for tests. Create interfaces for demonstrated
variation or isolation, not speculative ports and pass-through wrappers.

Use [DEEPENING.md](DEEPENING.md) for consolidating scattered behavior and
[DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md) for consequential interface choices.
When refactoring, start from a passing candidate and improve names, cohesion,
encapsulation, and justified boundaries within scope. Remove accidental duplication
and unnecessary complexity without unrelated cleanup. Add invariant tests only
where accepted behavior justifies them; rerun affected checks after edits and
retain criterion mapping. Record a no-change review when no improvement is needed.
Preserve behavior and acceptance criteria during refactoring. Architectural
boundary changes go before Gate A or return to Specifier when discovered later.
Reviewer reports findings; it does not silently edit or redesign the candidate.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
