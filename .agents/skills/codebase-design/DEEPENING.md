# Deepening

Classify dependencies before consolidating behavior: in-process computation can
be tested directly; local-substitutable I/O can use temporary fixtures; remote
owned or external services may need an explicit transport adapter. Introduce a
port only when variation or test isolation justifies it. Internal dependencies
need not enlarge the public interface.

Move scattered decisions behind a cohesive interface and test observable results
there. Replace obsolete implementation-coupled tests only after equivalent
behavioral coverage is observed. Do not delete unique regressions just because
modules merged. Preserve accepted behavior and route architectural scope changes
through the Specifier instead of hiding redesign in refactoring.
