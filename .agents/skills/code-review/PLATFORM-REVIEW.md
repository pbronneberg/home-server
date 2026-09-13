# Platform review

Adapted from the repository's platform review skill by pbronneberg, version
1.2.0, under Apache-2.0. See [LICENSE-APACHE-2.0](LICENSE-APACHE-2.0).
The accompanying semantic rubric and evaluation cases retain that attribution.

Use this procedure within the single code review for Kubernetes, Helm, Flux,
secrets, storage, ingress, DNS, TLS, CI, recoverability, and operational impact.
Review read-only; return all candidate corrections to Coder.

## Establish scope and rules

Read `AGENTS.md`, `.github/instructions/repository.instructions.md`, and
`.github/instructions/home-platform.instructions.md`. For shared authentication
or Grafana routing, also read `.github/instructions/platform-auth.instructions.md`.
These rules apply before implementation regardless of the selected role.

Identify affected workloads, namespaces, hosts, storage, secrets, automation,
and recovery paths within the candidate scope established by code-review.
Use [the semantic rubric](references/semantic-review-rubric.md) for relevant
questions. During specification-time planning, use it to define expected outcomes
and evidence requirements; an implemented candidate and executed checks are not
prerequisites for planning.

## Use deterministic evidence during candidate review

Reuse attributable current results. Collect missing or invalidated evidence:

- `python3 scripts/review-evidence.py --output /tmp/home-server-review-evidence.json`
- `make ci` for implementation reviews when required tools are available.
- `make public-check` when changes may expose topology, credentials, local
  exports, or publication-sensitive history.

Treat the report and observed command output as authoritative for their checks.
Investigate every `requires_judgment: true` item: code detected a sensitive
condition but has not decided whether a migration or trade-off is acceptable.
Do not manually repeat or contradict findings without explaining the evidence
gap. Record failed, warning, and skipped checks with exact reasons. Never claim
success without observed output or status; an unavailable environment leaves
its corresponding claim unproven.

## Assess operational consequences

Summarize the intended outcome and deployment assumptions. Distinguish repository
evidence, deterministic findings, and reviewer inference. Apply the rubric to
architecture suitability, complexity, recovery credibility, operational clarity,
migration quality, and combined risk.

Prioritize data loss, secret exposure, loss of recovery capability,
authentication bypass, GitOps lockout, and unreviewed deployment automation.
Report only actionable findings supported by evidence; do not invent risks to
make a review appear thorough. Put these findings in code-review's single report,
keeping operational judgment distinguishable from standards and spec mismatches.

## Behavioral evaluation

Use [evaluation cases](references/evaluation-cases.md) only for model-dependent
behavior. Deterministic rules belong in executable tests. The report's Decision
is a reviewer recommendation; it never approves a required human gate.
