# Behavioral test quality

A good analyzer test feeds a public entry point a small fixture containing a
specific defect and asserts the documented finding. Its expected result comes
from the specification or an independently worked example. A valid control
fixture demonstrates that the rule does not flag safe input.

A bad test reads private helpers, mirrors their calculations, or checks that
an internal collaborator was called. Another weak test checks only that no
exception occurred when a particular error must be detected. Choose assertions
that would fail under a plausible wrong implementation. Preserve meaningful
outcome coverage across refactoring rather than internal test structure.

## Test sensitivity and failure paths

When hardening accepted behavior, choose relevant malformed inputs, absent
configuration, denied access, dependency failures, and recovery paths at the
accepted boundary. Cover meaningful risks rather than maximizing test counts.

Where it answers a concrete doubt about sensitivity, use a focused negative
control or temporary reversible fault representing a plausible defect. Observe
that the check fails, restore the candidate, and observe the accepted case pass.
Record both observations and the final candidate identity. Do not require new
mutation infrastructure or numerical scores. Evidence must show the system's
response, not a helper manufacturing the expected outcome.

Add coverage only for accepted behavior. A production defect returns to Coder;
ambiguous expectations return to Specifier. Run affected checks and send changed
tests through the affected downstream review under the shared pipeline contract.
Record unavailable checks and residual risks instead of treating missing evidence
as a successful control.
