---
name: style-review
description: "Review a diff against backend repo conventions: LLM-vs-human style rules, defensive-coding posture, naming consistency, error handling. Outputs ReportFindings or clean pass."
priority: high
model: sonnet
allowed-tools: "Bash, Read, Edit, Write"
---

# Style Review for lists-backend

Validate a diff against this repo's stated conventions (CLAUDE.md, PR_GUIDE.md, README.md, docs/decisions.md) plus project-specific rules:

1. **Defensive coding posture**: Match the existing error-handling patterns in the file/layer. Required path params (e.g., `:collectionId` in Sinatra routes) should not be guarded with empty-string checks — they're structurally guaranteed by route matching. Genuine external boundaries (request bodies, cross-service calls) warrant validation; document any new guard clause's rationale.
2. **Duplicated logic**: Don't repeat the same guard clause or validation snippet across 2+ routes without extracting it into a shared helper. If copy-pasting is necessary, explicitly mark it (`# copy/paste from ... # end copy/paste`) and track it for future refactoring.
3. **Comment style**: Must explain *why*, not restate the next line. Avoid redundant comments like `# Update the reference` above an obvious `.map!`. Comments citing design-doc sections or PR numbers are red flags for elevated code review scrutiny.
4. **Naming consistency**: Route param naming has drifted (legacy `:collectionId`/`:listId` vs newer `:pid`/`:id`). Don't mix conventions in one PR — pick one and apply it consistently across all new routes, or document the deliberate transition.
5. **Error-handling clarity**: Keep pattern consistent file-to-file. Don't swallow exceptions silently in some routes and re-raise in others without a clear reason.

## How it works

1. Reads the current diff: `git diff --cached` if staged, else `git diff HEAD...main`.
2. Scans for mechanical violations first (capitalized section headers, empty-param guards on required routes, duplicated validation snippets).
3. Reads changed files for judgment-based violations (comment density, naming drift, error-handling inconsistency).
4. Reports findings via ReportFindings (most severe first) or "clean pass" if none found.

No findings reported for:
- Correctness bugs (undefined variables, throw vs raise, broken indentation, etc.) — those are a separate cleanup scope.
- Trivial formatting or whitespace changes.

## Invocation

```
/style-review
```

Run this before `git commit` or `git push` to catch violations early.
