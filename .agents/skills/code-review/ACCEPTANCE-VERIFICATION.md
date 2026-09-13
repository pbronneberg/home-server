# Acceptance verification

Use this procedure for specification-time QA input and final verification of an
accepted specification. Keep expected outcomes independent of implementation;
deterministic standards evidence does not replace the acceptance oracle.

During specification, define observable outcomes and accepted test boundaries
with operator and developer input. Identify the system under test, governed
inputs, setup, probes, and expected observations. Retain the criterion mapping
and specification revision; reuse agreed boundaries. Planning does not require
an implemented candidate or diff base.

During final verification, require an identified accepted specification and
candidate. Execute probes only in authorized environments and within authorized
actions; this procedure grants no live access or mutation permission. Record an
unauthorized or unavailable probe as a blocker with the next operator action.
Execute the accepted procedure against the identified
candidate, including staged, unstaged, and in-scope untracked changes. Capture
actual commands, environment, observations, report references, and relevant
negative controls. Do not substitute mocked or helper-generated outcomes for a
claim about the actual system.

For every criterion, record attributable pass/fail evidence or an explicit
blocker. Separate static/render evidence from live-system evidence: missing
access or an unavailable environment blocks its corresponding claim. Check
operator documentation and agent guidance for specification drift. Preserve
nonclaims, residual risks, and independent-context limitations.

Route failures to the owning stage under the shared pipeline contract, and
require affected evidence again after edits. Do not repair the reviewed candidate
or change expectations to fit it. Supply the criterion-by-criterion packet and
an accept/reject recommendation using `handoff`; only the human can accept Gate B.
