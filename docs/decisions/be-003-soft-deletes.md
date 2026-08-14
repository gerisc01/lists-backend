---
id: be-003
date: 2026-04-20
title: "Soft deletes"
feature: conventions
repo: be
---

# Soft deletes

**Context**: Mobile/offline sync clients need to know what was deleted since their last sync.

**Decision**: `delete!` sets `deleted: true` on the record rather than removing the file. `list({since:, include_deleted: true})` returns deleted records so clients can remove them locally.

**Rationale**: Without soft deletes, a client that syncs infrequently has no way to learn about deletions.
