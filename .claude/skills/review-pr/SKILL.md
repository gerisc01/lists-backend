---
name: review-pr
description: "Run style, comment, and doc review on the branch diff in one pass: apply the clear fixes, report what needs a person. Use before opening or updating a PR."
allowed-tools: "Agent, Bash, Read, Edit, Grep, Glob"
---

# Review PR for lists-backend

One command for "is this branch ready?". Correctness is `/code-review`, run separately.

```
/review-pr
  ├─ style-review   --report  ┐
  ├─ comment-review --report  ├─ parallel subagents, read-only
  └─ doc-review     --report  ┘
        ↓
  merge → apply the clear fixes → verify
        ↓
  report: what changed · what needs you
```

`/review-pr --report` stops after the merge and edits nothing.

## Procedure

1. **Scope.** `git diff --name-only main...HEAD` plus uncommitted changes. Nothing changed → stop.
2. **Review.** Launch three `general-purpose` agents in one message, `model: sonnet`. Each prompt:
   > Read `.claude/skills/<name>/SKILL.md` and follow it with `--report` on the branch diff
   > (`main...HEAD` plus uncommitted changes). Edit nothing. Return only a list of findings, one
   > per line: `file:line | finding | fix | applied-or-you`, where `applied` means the skill marks
   > this kind of fix as applied.
3. **Merge.** Group by file. Two findings on the same lines are one finding — keep the more
   specific fix. A comment review "tangled code" note and a style "readability" finding merge
   into the style one.
4. **Apply** every `applied` finding, one file at a time.
5. **Verify.**
   - `ruby scripts/comment_audit.rb --verify` if only comments changed in a file.
   - `bundle exec rake test TEST=<file>` for the tests covering touched files if code changed.
   A failure → revert that fix and move it to *needs you* with the output.
6. **Report.**

## Report

```
Changed
  src/actions/move_item.rb:12     style    renamed :collectionId → :id
  src/type/placement.rb:40        comment  cut — restates the next line
  README.md:52                    doc      dates_api.rb → placements_api.rb

Needs you
  src/actions/occurrences.rb:88   comment  suggest: week_start comes from the client grid (games-lists …)
  src/api/placements_api.rb:30    style    logic in the route — move to src/actions/?
```

Empty sections are omitted. A clean branch is one line.
