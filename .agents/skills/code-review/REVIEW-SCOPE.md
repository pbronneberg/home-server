# Complete candidate scope

Resolve the supplied base and pin its merge base with HEAD. Record HEAD and base
SHAs. Collect `git diff <merge-base> HEAD`, `git diff --cached`, `git diff`, and
`git ls-files --others --exclude-standard`; inspect untracked contents too.
Use `git status --short` to identify additions, deletions, and renames. Do not
stage, checkout, clean, stash, commit, or rewrite anything while collecting.

Keep a digest of the tracked binary-capable patch plus sorted untracked names
and content hashes, or preserve equivalent immutable evidence snapshots. Do not
mistake HEAD alone for the candidate identity. Report unreadable or unavailable
content as a scope gap. A branch with no committed delta can still have a
reviewable working-tree change. Check identity again before final findings;
if content changed, refresh the scope and invalidate affected review evidence.
