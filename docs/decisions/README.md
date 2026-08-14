# Decisions

One decision per file, numbered, **append-only**. Start at **[`INDEX.md`](INDEX.md)** — generated,
grouped by feature, superseded entries struck through.

Format and rules are canonical in the frontend repo:
[`games-lists/docs/decisions/README.md`](../../../games-lists/docs/decisions/README.md). In short:
only forward links (`supersedes`, `amends`) are authored; `status` and the reverse links are derived.

**Backend ids carry a `be-` prefix** (`be-004-cross-collection-staging-pile.md`) so the two repos'
numbering never collides when they cross-reference. Frontmatter uses `repo: be`.

A decision spanning both repos is written **once**, in the repo where its primary mechanism lives,
with `repo: both`.

## Generating and checking

The generator lives in the frontend repo — this one is Ruby and shouldn't grow a node dependency
just to build an index. It resolves `lists-backend` as a sibling directory and writes both indexes:

```
node ../../../games-lists/scripts/check-docs.js
node ../../../games-lists/scripts/check-docs.js --check
```

## Retired vocabulary

Entries written before 2026-08-13 use retired words — *ghost*, *phase*, *catalog item*. They are
records of what was decided then and are not rewritten. See
[`GLOSSARY.md`](../../../games-lists/docs/GLOSSARY.md).
