---
id: be-001
date: 2026-04-20
title: "Dates grouped by collection, not list"
feature: weekly-planning
repo: be
---

# Dates grouped by collection, not list

**Context**: Date queries (`/api/dates/:day/:collection/items`) need to aggregate items across many lists in a single view (e.g., a weekly planner pulling from multiple lists).

**Decision**: The dates API groups items by collection rather than by list.

**Rationale**: A user's "today view" or "week view" spans all their lists within a collection. Grouping by list would require multiple calls or a separate aggregation layer.
