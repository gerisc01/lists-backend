---
name: doc-review
description: "Review docs on the branch diff (or a given path, or a plan in the session): does this change need a doc update, is each doc true against the code, and does it follow CLAUDE.md § How to write here. Applies the clear fixes; reports the rest."
model: sonnet
allowed-tools: "Bash, Read, Edit, Grep, Glob"
---

# Doc Review for lists-backend

| Invocation | Reviews |
|---|---|
| `/doc-review` | this branch: `git diff main...HEAD` plus uncommitted changes — code and Markdown |
| `/doc-review <path>` | that doc, in full |
| `/doc-review` *(with a plan in the session)* | the plan, before it's built |

| `... --report` | same, but edit nothing — `/review-pr` uses this |

**Applied:** a claim the code refutes, a stale path or name, history, restated text.
**Left for you:** a new doc or section, moving a fact to another doc, and reshaping prose into a
table or diagram.

## What each doc owns

| Doc | Owns | Reader |
|---|---|---|
| `README.md` | run, test, how it works, where changes go | anyone starting work |
| `SCHEMA.md` | what the `ruby-schema` gem generates for a type | anyone touching `src/type/` |
| `API.md` | every endpoint — kept current by `/api-docs` | client authors |
| `STYLE_GUIDE.md` | how code is shaped | author, `/style-review` |
| `PR_GUIDE.md` | PR size, branch names, description template | author |
| `CLAUDE.md` | rules for agents, tooling | agents |

A fact lives in one doc; the others link to it. Next steps and the backlog live in `../games-lists`
(`NEXT.md`, issues labelled `be`), not here.

## Procedure

**On a diff:**

1. **Does the change need a doc update?** For each changed code file, find the doc sections that
   describe it: the `README.md` "Where changes go" row and "How it works" table, `SCHEMA.md`, any path or symbol
   named in a doc (`grep`). Then ask:
   - Does a doc now say something false? (renamed file, moved responsibility, new route branch)
   - Does the change add something a doc's table or diagram lists? (a new layer, screen, pattern)
   - Did a route, param, or response shape change? Run `/api-docs` for `API.md`.
   No doc is affected is a valid answer — say which sections you checked.
2. **Review the changed Markdown** as below.

**On a doc:**

1. **Check each claim against the code.** A path: `ls` it. A symbol: grep it. A behavior: read it.
   Report a false claim with the `file:line` that refutes it.
2. **Check the rules:**
   - Current state only — no history, "used to", dates, or decision logs.
   - In the doc that owns it — otherwise move it and link.
   - `CLAUDE.md` § How to write here: a table or example over narrating prose; one recommendation,
     not a survey; explained once; no pre-empted follow-ups.

**On a plan:** only the writing rules.

## Reporting

Each finding is a concrete edit: "`README.md:52` names `dates_api.rb`, now `placements_api.rb` — rename"
or "lines 40–58 restate the table above — cut". A finding that doesn't say what replaces the text
isn't actionable.

## Do not

- Cut a doc's only example.
- Restyle voice. Shortening is in scope.
- Add a doc or a section without a reader who needs it — suggest it instead.
