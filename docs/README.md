# Docs Index

**Start here.** The backend half of a two-repo project: **`lists-backend`** (be — Ruby) and
**`games-lists`** (fe — React Native).

Domain vocabulary is **canonical in the frontend repo**: [`../../games-lists/docs/GLOSSARY.md`](../../games-lists/docs/GLOSSARY.md).
Don't duplicate it here — placement, ghost, staging and friends mean the same thing on both sides,
and two copies drift.

---

## What do you want?

| I want to… | Go to |
|---|---|
| know what to work on next | [`../../games-lists/NEXT.md`](../../games-lists/NEXT.md) — one list, both repos |
| find everything about one feature | [`features/`](features/) — pages here cover backend-only concerns; cross-repo features live in the fe repo and their manifests name backend paths |
| know which feature a source file belongs to | [`features/BY-FILE.md`](features/BY-FILE.md) *(generated)* |
| know **why** something is built the way it is | [`decisions/INDEX.md`](decisions/INDEX.md) |
| see the system map | [`architecture.md`](architecture.md) |
| run, test, or seed the server | [`development.md`](development.md) |
| read the HTTP API | [`../../games-lists/API.md`](../../games-lists/API.md) — generated from this repo's source |
| open a PR | [`../PR_GUIDE.md`](../PR_GUIDE.md) |

---

## Conventions

Same three doc kinds as the frontend — **feature page** (living), **decision** (append-only,
numbered, immutable), **snapshot** (frozen, in `history/`). Decision frontmatter carries
`repo: fe | be | both`, so a decision that spans both repos is written **once**, in the repo where
its primary mechanism lives, and referenced from the other.

Next steps never live here or in session memory. They live in `NEXT.md`.
