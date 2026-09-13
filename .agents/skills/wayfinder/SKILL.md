---
name: wayfinder
description: "Map a large uncertain effort into linked decision tickets and resolve its design with the user before specification."
license: MIT
compatibility: Repository checkout and host file-reading tools; Git for candidate evidence.
metadata:
  author: Matt Pocock; repository maintainers (adaptation)
  upstream: https://github.com/mattpocock/skills/tree/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/wayfinder
  upstream-revision: "3cca18b368ae95cdbdebbff572ccafa662551015"
  requires-skills: "grilling,domain-modeling,research,prototype,to-spec,handoff"
---

# Wayfinder

Produce decisions, not an implementation backlog. A clear bounded task goes
straight to specification. Read [MAP-AND-TICKETS.md](MAP-AND-TICKETS.md).

## Chart

Use `grilling` and `domain-modeling` to name the destination and scope. Explore
breadth first: precise questions become tickets even if blocked; areas too
uncertain to phrase stay in Not yet specified. Draft a `wayfinder:map` issue and
child decision issues; create identities before wiring native blocking edges.
Keep the map an index of named links and one-line gists. Detailed resolutions
live in decision issues; query open children rather than duplicating their state.
Stop charting at a useful frontier. Research may proceed independently within
authorization; never silently resolve design choices while the user is away.

## Resolve

Load the map and choose the requested ticket or first open, unblocked, unclaimed
child. Check assignment before claiming through the tracker when authorized.
A local draft cannot claim a remote ticket; report that concurrency limitation.
Read linked resolutions as needed rather than every ticket at once.

- Research gathers primary-source facts with `research`.
- Prototype makes a choice concrete with `prototype`; the user supplies design
  reactions and acceptance.
- Grilling uses `grilling` and `domain-modeling`; never answer for the user.
- Task completes a prerequisite to a decision, within existing authorization.
  The map does not authorize provisioning, live changes, or handling credentials.

Work one human decision per session by default; independent research may be
batched. Record the answer and evidence in a resolution comment, close only
resolved tickets, and append a named link to Decisions so far. If publication
is unavailable or unauthorized, prepare those updates as drafts instead.
Graduate newly precise questions from fog into tickets, then wire blockers.
Excluded tickets get a scope reason, not a successful decision resolution.
Re-read tracker state before updating to respect other sessions.

When open decisions and in-scope fog are empty, hand linked resolutions to
`to-spec`, followed by implementation tickets under the accepted spec. Human
decisions stay unresolved until the human answers, including without subagents.

## Repository integration

Read `.github/instructions/agent-pipeline.instructions.md` for stage contracts
and gates, and `docs/agents/issue-tracker.md` for GitHub records and local drafts.
Load named dependencies using host-supported invocation or read their files at
`.agents/skills/<name>/SKILL.md`. Existing user authorization takes precedence;
this skill grants no authority to publish, commit, or operate live systems.
