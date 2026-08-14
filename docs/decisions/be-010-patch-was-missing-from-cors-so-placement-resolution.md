---
id: be-010
date: 2026-08-07
title: "PATCH was missing from CORS, so placement resolution never worked in a browser"
feature: conventions
repo: be
---

# PATCH was missing from CORS, so placement resolution never worked in a browser

`src/base_api.rb` set `allow_methods` to `GET,POST,PUT,DELETE,OPTIONS` in both CORS blocks.
`PATCH /api/placements/:pid` is the only way a placement's resolution is written — complete,
skip, and reopen all route through it — so every browser preflight for that route failed and
those three actions silently did nothing on web. Added PATCH to both blocks.

**Why it survived so long:** the two layers that should have caught it structurally cannot.
Native has no CORS, and the frontend's Jest suite mocks the API module, so both saw a passing
"complete" path. Only a real browser against a real server exercises the preflight. It was found
within minutes of the Playwright spine test existing — the whole argument for having one.

A secondary bug rode along: the client's `throw error.response.data.message` has no null guard,
so a CORS failure (no `error.response`) surfaced as `TypeError: Cannot read properties of
undefined` instead of the real cause. Tracked frontend-side; not fixed here.

**Guarded by** `test/cors_methods_test.rb`, which asserts every HTTP verb appearing in
`src/api/*.rb` route definitions is present in every `allow_methods` block — so adding a route
with a new verb fails the suite until CORS is updated. It is a static check on purpose:
`test/test-api.rb` builds a trimmed `Api` without `register Sinatra::Cors`, and loading
`src/base_api.rb` into that shared class would leak its routes and settings into every other
suite in the run.
