# Dependency substitutes

Prefer real in-process behavior and temporary local fixtures. Substitute at
external system boundaries, time, or randomness when needed for deterministic
checks. Pass dependencies explicitly when isolation is justified; do not expose
private collaborators only so tests can mock them. Use realistic known inputs
and outputs, not a mock that simply returns what the assertion expects.
A fake cluster or rendered manifest cannot establish live behavior: report the
scope of evidence and retain the corresponding live acceptance requirement.
