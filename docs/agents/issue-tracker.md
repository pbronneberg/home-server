# Work records

GitHub issues and pull requests are the default working record. Resolve the
repository from the checkout's Git remote using the host's GitHub integration
or `gh`; do not hard-code an account, private URL, or machine path.

## Authorization and drafts

Read existing issues before creating replacements. Publish, assign, comment,
close, or change labels only within the user's authorized tracker work. A request
to implement repository files alone does not authorize posting messages. Prepare
a concrete draft in `.local/agent-work/` when publication is unavailable or not
authorized, and report that it is a local draft. Never invent issue numbers or
claim native dependencies were created when only text links were written.

Do not store secrets, real topology, raw operational logs, or access credentials
in issues, handoffs, or public artifacts. Refer to encrypted configuration and
redacted evidence. Local drafts remain private working context, not a second
accepted specification.

## Wayfinding operations

- Create one map issue labelled `wayfinder:map`. Keep its destination, notes,
  decisions-so-far links, unresolved areas, and exclusions concise.
- Create decision questions as sub-issues, labelled `wayfinder:research`,
  `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`. A prerequisite
  task unblocks a decision; it is not an implementation deliverable.
- Create issues before wiring native blocking relationships. When the client
  cannot manage native relationships, use named links under `Parent` and
  `Blocked by`, explicitly record the fallback, and inspect linked issues before
  selecting work. Never infer independence from the absence of a client field.
- The frontier contains open, unblocked, unclaimed child issues. Claim the
  selected ticket by assignment when authorized; otherwise record a local claim
  and disclose that it does not coordinate concurrent sessions.
- Work one human decision ticket per session. Independent research may be
  delegated when supported and authorized. Human design choices require the
  human's answer; an elapsed wait is not approval.
- Put the answer in a resolution comment, close the resolved ticket, and add a
  named link with a one-line result to the map. Move newly precise questions out
  of unresolved areas into tickets. Superseded decisions retain their history
  and link their replacements; reopen affected work and approvals.

## Specifications and implementation tickets

Use one specification issue per bounded change, or a parent specification with
independently verifiable child implementation tickets for multi-session work.
Use `ready-for-agent` only when the ticket is unambiguous and any required Gate A
approval is present. Create missing labels only as part of authorized tracker
setup; otherwise describe the intended label in the draft.

An implementation ticket contains outcome, scope and exclusions, acceptance
criteria with stable IDs, blocking links, accepted test boundaries, environment
assumptions, rollback requirements where relevant, and the approved QA procedure.
The QA procedure names the system under test, setup, probes, expected success and
failure results, negative control, evidence to retain, and limits of the claim.

Gate A approval must identify the exact specification snapshot (for example an
immutable approval comment quoting the accepted packet, or a content digest of
retained text). An editable issue URL alone is not a frozen specification.
Gate B is a human disposition of a named candidate and evidence package.
Existing explicit approval may satisfy either gate for the same scope and
revision; automation must never fabricate a human disposition. Final evidence
acceptance is not permission to deploy or merge.

## Stage handoffs and candidate identity

Keep stage handoffs on the implementation issue or PR, using the shared pipeline
contract in `.github/instructions/agent-pipeline.instructions.md`. A portable
handoff points to those records instead of copying competing versions.

Identify the base and candidate commit. For work in progress, also retain a diff
and content identity for all non-ignored untracked files in scope. A practical
read-only collection is:

```sh
git rev-parse HEAD
git merge-base <base-ref> HEAD
git diff --binary <resolved-merge-base> --
git diff --cached --name-status
git diff --name-status
git ls-files --others --exclude-standard -z
```

The combined diff covers committed, staged, and unstaged tracked changes; read
and hash the named untracked files separately, including their relative paths.
Use NUL-safe processing for filenames. Keep the captured diff and untracked
manifest in ignored local storage, with a SHA-256 digest in the handoff. Review
only the agreed scope and do not print private contents into public records.
Recompute identity before accepting evidence. Edits require rerunning affected
checks and downstream reviews; do not attach old results to a new candidate.

The existing evidence collector remains authoritative for its implemented
rules and declared scope. It does not attest to every untracked file or to live
cluster behavior; supplement it with the complete review inventory above.

## Durable documentation

Keep accepted architecture decisions in `docs/decisions/`, operator procedures
in the relevant existing runbook, and a glossary in `CONTEXT.md` only when useful
terms have actually been agreed. Do not create placeholder documentation or a
parallel specification system. Promote approved decisions from working issues
with links and a clear source of truth.
