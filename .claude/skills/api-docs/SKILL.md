---
name: api-docs
description: "Bring API.md in line with the route handlers and types. Default updates only what drifted; --full regenerates it. Reads Ruby source, never other docs."
allowed-tools: "Agent, Bash, Read, Edit, Write, Grep, Glob"
---

# API Docs

`API.md` describes every endpoint for a client author. The handlers are the truth: where `API.md`
and the code disagree, the code wins.

| Invocation | Does |
|---|---|
| `/api-docs` | find drift, update only those sections |
| `/api-docs --full` | regenerate the whole file |

## Drift check

1. **Routes.** List every route:
   `grep -rhoE "^\s*(get|post|put|patch|delete) ['\"][^'\"]+" src/api`
   plus the five from each `generate_schema_crud_methods '<endpoint>', <Type>` and the one from each
   `generate_schema_endpoint(:<kind>, '<endpoint>', <Type>)` (see `list_api_framework.rb`). Compare
   paths with `API.md`, parameter names aside. Report added and removed paths.
2. **Changed since the last update.** `git log -1 --format=%H -- API.md`, then
   `git diff <that>..HEAD --stat -- src/api src/type src/actions src/exceptions*.rb`. More than a
   handful of files → run `--full` instead. Otherwise read each
   changed handler and type, and check the sections of `API.md` that cover it: params, request
   body, response shape, status codes.
3. **Update** those sections only. Keep the file's structure.
4. **Report** what changed, and anything you couldn't settle from the code.

## Full regeneration

Launch a `general-purpose` agent, `model: sonnet` — the delta-sync rules and recurrence shapes carry
too much meaning for a smaller model. It reads `src/` and writes `API.md` with:

| Section | Must include |
|---|---|
| Base URL and auth | the `ACCOUNT_ID` header; which routes skip it |
| Delta sync | `?since=` on list, get, and sub-resource reads; when each returns `200 {objects, deleted_ids}`, `204`, or a plain array |
| Errors | status per `ListError` class; the body is `{error, message}` |
| Every endpoint | method, path, params, request body, response shape, status codes — grouped by resource |
| Shapes | every type in `src/type/`, including `scheduling`, `recurrence`, `status`/`transitions`, `resolution`, ghost occurrences |
| Action steps and template field types | from `src/actions/item_actions.rb` and `src/type/template_types/` |

No generation date or machine path in the file — `git log` has both. Then run the drift check
against the result.

## Do not

- Copy from `README.md` or `SCHEMA.md` — read the code.
- Add history or "legacy" notes beyond what the code itself marks.
