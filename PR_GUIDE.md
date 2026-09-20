# Pull Request Guide

---

## Philosophy

PRs in this project serve two purposes: keeping a readable history of *why* things changed, and making it easier to re-orient when coming back to the code after time away. Since the team is small, the overhead should be minimal — but a little structure at the start of a feature pays off when you return to it weeks later.

---

## Starting a Feature

Before writing code, define the PR boundary. A good PR answers one question: **"What is the smallest coherent change to this codebase?"**

The natural split points follow the architecture layers:

- **Type layer** — changes to `src/type/` (schema definitions, template types)
- **API layer** — changes to `src/api/` (routes, framework helpers)
- **Actions layer** — changes to `src/actions/`
- **Infrastructure** — changes to `src/storage.rb`, `src/base_api.rb`, `src/exceptions*.rb`
- **Test-only** — no source changes, tests only

If a change touches only one layer, it's usually one PR. Backend changes are often the exception — types, API routes, and actions are frequently coupled, and it can make more sense to ship them together than to split artificially. Use judgment: if separating them would require half-baked intermediate state, keep them together and say so in the description.

**Hard limits — if a PR crosses these, split it:**
- Both a new feature and a refactor in the same PR
- Changes to the storage/infrastructure layer bundled with unrelated feature work
- A large new feature and a separate bug fix in the same PR

---

## Scope Creep

The most common trap: noticing something unrelated while working on a feature and fixing it in the same branch.

**The rule:** If it wasn't broken when the branch started, it doesn't go in this PR.

Note it and handle it as a follow-up. The exception is a single-line fix in a file you're already modifying for the feature — that's fine to include, but call it out explicitly in the PR description.

---

## Branch Naming

```
feature/<short-description>     # New functionality
fix/<short-description>         # Bug fix
refactor/<short-description>    # No behavior change
test/<short-description>        # Tests only
```

Examples: `feature/recurring-events`, `fix/day-cache-stale-on-delete`, `refactor/list-api-framework`

---

## PR Description Template

When you're ready to open a PR, ask Claude to generate the description. It will produce a title and body in this format.

**Title** (80 characters max):
```
<type>: <short description of what changed and why>
```
Common types: `fix`, `feat`, `refactor`, `test`, `chore`. The description should complete the sentence "This commit will…" — e.g. `feat: add recurring event support to dates API`.

**Body:**
```markdown
## What
[1-3 sentences on what changed and why. Focus on intent, not mechanics.]

## How it fits together
[Which layers were touched and how they connect — e.g., "The new RecurringDate
template type validates the spec; DateHelpers orchestrates the parent-child item
lifecycle; the dates API exposes the three new endpoints." This is the section
that answers "how do all the bits connect?" without requiring the reviewer to
trace through the code.]

## Files changed
[Grouped by layer — types, API, actions, infrastructure, tests.
One line per file with a note on what changed in it.]

## Docs
[Whether README.md, SCHEMA.md, API.md or CLAUDE.md needed a change — see below.]

## Out of scope / follow-up
[Anything noticed but intentionally left out of this PR.]

## Testing
[What was tested and how — e.g., "Added unit tests for the new validation path.
Ran full rake test suite." or "Covered by existing dates_test.rb."]
```

The *How it fits together* and *Docs* sections are the most important ones for this project.

---

## Docs section

For each of `README.md`, `SCHEMA.md`, `API.md` and `CLAUDE.md`, say whether this PR changed what it describes.
If none needed a change, say which sections you checked.

---

## Reviewing Your Own PRs

Before merging:

1. **Does the diff tell a coherent story?** If you have to jump around to understand what's happening, the PR may need to be split or the description needs more context.
2. **Is there anything in the diff you don't recognize?** Stray changes, debug output, or accidentally included files should be cleaned up.
3. **Does the PR description still match the diff?** If scope shifted during development, update the description before merging.
4. **Did you complete the documentation check above?** The `## Docs` section should be present in every PR description.

---

## What Claude Can Help With

At any point during a feature:

- **"Is this getting too big?"** — Describe what you've changed so far and what's left; get a recommendation on whether to split.
- **"What would the PR description look like?"** — Provide the branch and a brief summary of what changed; Claude will draft the full description from the code.
- **"Is this in scope?"** — Describe the thing you noticed and the original feature goal; get a recommendation on whether it belongs in this PR.
- **"What questions might come up on this PR?"** — Claude can anticipate likely review questions and draft answers, useful before you commit and move on.
