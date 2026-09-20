---
name: style-review
description: "Review code structure on the branch diff (or a given path) against STYLE_GUIDE.md: placement, naming, route shape, error handling, habits, test conventions. Ignores comments. Applies the clear fixes; reports the rest."
model: sonnet
allowed-tools: "Bash, Read, Edit, Grep, Glob"
---

# Style Review for lists-backend

Checks that code is shaped the way `STYLE_GUIDE.md` says. Comments are `/comment-review`'s job;
correctness bugs are `/code-review`'s.

| Invocation | Reviews |
|---|---|
| `/style-review` | this branch: `git diff main...HEAD` plus uncommitted changes |
| `/style-review <path>` | that file or directory |
| `... --report` | same, but edit nothing — `/review-pr` uses this |

**Applied:** a rule the guide states outright and a fix that stays inside the changed files — a
param rename, `unless` → `if !`, an explicit `return`, `JSON.parse` → `get_json_payload`,
`throw` → `raise`, a test name, a teardown the wrapper already covers.
**Left for you:** moving logic out of a route, extracting a helper, replacing a silent return or a
blanket rescue (the right error needs judgment), moving files, and guide gaps.

## What it checks

| Area | Look at |
|---|---|
| Placement | the folder matches § File & Folder Organization; shared logic lives in `src/actions/` or a helper |
| Naming | the § Naming table; route params are camelCase and say what they identify |
| Routes | simple CRUD inline; anything more calls a helper or action; `get_json_payload`; explicit `status` and `body` |
| Error handling | a specific `ListError` raised where the problem is found; no silent `return` on an unexpected nil; no `rescue Exception`; no `throw` |
| Habits | explicit `return`; `if !` not `unless`; `.to_s.empty?`; code copied twice becomes a helper |
| Actions | one top-level `def` per file, named after the file |
| Tests | `MinitestWrapper`; setup only what's needed; `teardown` only for what the wrapper doesn't clear; `test_<thing>_<case>` / `_failure` |
| Readability | code a reader can't follow without a comment — restructure it instead |

## Procedure

1. List the changed `.rb` files, then read each in full — a finding depends on the file's shape.
2. For each area, compare the change with `STYLE_GUIDE.md` and with neighboring files, preferring
   files last changed before 2026 when neighbors disagree.
3. Apply the fixes marked *applied*, then run `bundle exec rake test TEST=<file>` for the tests
   covering touched files.
4. Report each finding as `file:line`, the rule it breaks, and the fix, most severe first, marking
   what was applied.

A pattern that looks wrong but no rule covers is a finding against `STYLE_GUIDE.md`: report it as
"guide gap", not as a violation.

Skip whitespace and formatting.
