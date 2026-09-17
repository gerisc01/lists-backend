# Lists Backend API Documentation

Code is the single source of truth; where any other doc disagrees with a handler, the handler wins.

---

## Table of Contents

1. [Base URL and Authentication](#1-base-url-and-authentication)
2. [Delta-Sync Caching Protocol](#2-delta-sync-caching-protocol)
3. [Error Response Format](#3-error-response-format)
4. [Common Response Fields](#4-common-response-fields)
5. [Resources](#5-resources)
   - [Accounts](#accounts)
   - [Collection Groups (boards)](#collection-groups-boards)
   - [Collections](#collections)
   - [Lists](#lists)
   - [Items](#items)
   - [Item Groups](#item-groups)
   - [Templates](#templates)
   - [Tags](#tags)
   - [Actions](#actions)
   - [Placements](#placements)
   - [Occurrences (recurring, ghost/materialize)](#occurrences)
   - [Reconcile](#reconcile)
   - [Dates — LEGACY (dormant)](#dates-legacy-dormant)
6. [Complex Data Model Shapes](#6-complex-data-model-shapes)
   - [Collection](#collection-shape) / [CollectionGroup](#collectiongroup-shape) / [ListGroup](#listgroup-embedded-shape)
   - [List](#list-shape)
   - [Item](#item-shape) / [Instances (repeat engagement)](#instances-repeat-engagement) / [Scheduling](#scheduling-shape) / [Recurrence rule](#recurrence-rule-shape) / [Status & Transition](#status--transition-shape) / [Energy](#energy-shape) / [Query language](#query-language)
   - [Placement](#placement-shape) / [Resolution](#resolution-shape)
   - [Ghost occurrence](#ghost-occurrence-shape)
   - [ItemGroup](#itemgroup-shape)
   - [Template and Field](#template-and-field-shape)
   - [Action and ActionStep](#action-and-actionstep-shape)
   - [Tag](#tag-shape) / [Account](#account-shape)
   - [Day and DailyItem — legacy, still-live storage type](#day-and-dailyitem-shape)
   - [Legacy recurring item fields](#legacy-recurring-item-fields)
7. [Action Step Types](#7-action-step-types)
8. [Template Field Types](#8-template-field-types)
9. [Sub-Resource and Cascade Patterns](#9-sub-resource-and-cascade-patterns)

---

## 1. Base URL and Authentication

The server runs on port `9090` by default (`BaseApi.start(port:, bind:)`). All resource routes live in the `Api` class (`src/base_api.rb`); every `*_api.rb` file under `src/api/` reopens it. `Api`'s `before` filter is the one that actually runs for these routes:

```ruby
before do
  if request.request_method != 'OPTIONS'
    protected! unless request.path_info == '/api/accounts' || TypeStorage.is_e2e_test
  end
  content_type 'application/json'
end
```

So every route requires auth **except**: `OPTIONS` (CORS preflight), `POST /api/accounts` (account creation), and everything when `TypeStorage.is_e2e_test` is set (E2E test mode — `LISTS_BACKEND_E2E_TEST` starts with `t`). `BaseApi` (a separate, unused-for-routing Sinatra app in the same file) has a near-identical filter without the e2e bypass; it exists for `BaseApi.start`'s server-boot logic, not for serving these routes.

```ruby
account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
account = Account.get(account_header)
```

Header name is exactly `ACCOUNT_ID`; its value may be the bare account id or `Bearer <id>` — the server takes the last space-separated token.

```
ACCOUNT_ID: <account-id>
```

**On failure:** `401`
```json
{ "error": "Unauthorized", "message": "Invalid API key" }
```

`GET`/`PUT`/`DELETE /api/accounts/:account_id` additionally re-run this same check inline (`src/api/account_api.rb`) — those routes aren't otherwise distinguished from any other authenticated account hitting them.

---

## 2. Delta-Sync Caching Protocol

Verified against `src/api/helpers/list_api_framework.rb` (`schema_endpoint_list`/`schema_endpoint_get`) and `src/api/helpers/api_helpers.rb` (`convert_since_format`).

### `?since=` on list endpoints (`GET /api/<type>`)

`since=now` (case-insensitive) is special-cased and replaced server-side with `Time.now.utc.iso8601`.

| Condition | HTTP Status | Body |
|---|---|---|
| No `since` param | `200` | Plain JSON array of all non-deleted objects |
| `since` provided, matching instances empty | `204` | `{"objects": [], "deleted_ids": []}` |
| `since` provided, matching instances non-empty | `200` | `{"objects": [...], "deleted_ids": [...]}` |

The underlying store query filters by `since` (`clazz.list(since:, include_deleted: true)`) before this layer sorts objects vs. deleted_ids.

### `?since=` on single-object endpoints (`GET /api/<type>/:id`)

| Condition | HTTP Status | Body |
|---|---|---|
| Object not found | `404` | _(empty)_ |
| `since` provided AND `instance.json['updated_at'] < since` | `204` | _(empty)_ |
| Otherwise | `200` | Full object JSON |

### `?since=` on sub-resource item-list endpoints

`GET /api/lists/:listId/items` and `GET /api/collections/:collectionId/listItems` build their own item array (flattened, deduped, includes group/child items) and run it through `ApiHelpers.convert_since_format`:

```ruby
since_instances = instances.select { |it| it['updated_at'] > since }   # strictly greater than
deleted_ids = since_instances.select { |it| it['deleted'] }.map { |it| it['id'] }
objects     = since_instances.reject { |it| it['deleted'] }
```

- Both `deleted_ids` and `objects` empty → `204`
- Otherwise → `200`

Without `?since=`, both endpoints return a plain array.

---

## 3. Error Response Format

Confirmed in `src/exceptions_api.rb`.

| HTTP Status | `error` field | `type` field | Raised by |
|---|---|---|---|
| `400` | `"Bad Request"` | `"Invalid JSON"` | Unparseable request body (`JSON::ParserError`) |
| `400` | `"Bad Request"` | `"Validation Exception"` | `ListError::Validation` (schema/template validation failure) |
| `400` | `"Bad Request"` | `"Bad Request Error"` | `ListError::BadRequest` (general) |
| `401` | `"Unauthorized"` | _(absent)_ | Missing/invalid `ACCOUNT_ID` (handled inline via `halt`, not this error map) |
| `404` | `"Not Found"` | _(absent)_ | `ListError::NotFound` |
| `500` | `"Internal Server Error"` | _(absent)_ | Any other unhandled exception |

```json
{ "error": "Bad Request", "type": "Validation Exception", "message": "Field 'name' is required" }
```

`404` and `500` bodies carry only `{error, message}` (no `type`).

---

## 4. Common Response Fields

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Auto-generated on creation (schema storage layer); can be supplied by the client on POST. |
| `updated_at` | `String` (ISO 8601) | Set by the storage layer on save; used for `?since=`. |
| `deleted` | `Boolean` | Present/`true` only on soft-deleted objects surfaced in delta-sync responses. |

---

## 5. Resources

### Accounts

`src/api/account_api.rb`. Account creation is the only unauthenticated route.

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/accounts` | Create an account. Body: `{ "name": "..." }` (required). Returns `201` + account object. |
| `GET` | `/api/accounts/:account_id` | Get account. `404` if not found. |
| `PUT` | `/api/accounts/:account_id` | Merge fields, validate, save. Returns `200` + updated object. |
| `DELETE` | `/api/accounts/:account_id` | Returns `204`. |

See [Account shape](#account-shape).

---

### Collection Groups (boards)

`src/api/collection_groups_api.rb`. A named, ordered, shared set of collections — the app's "board". Full CRUD, with a membership-scoped `LIST`:

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/collection-groups` | List, filtered to groups whose `members` includes the caller's account id (`members_only`). Non-deleted only. |
| `GET` | `/api/collection-groups/:id` | Get (supports `?since=`) |
| `POST` | `/api/collection-groups` | Create |
| `PUT` | `/api/collection-groups/:id` | Update |
| `DELETE` | `/api/collection-groups/:id` | Delete |

See [CollectionGroup shape](#collectiongroup-shape).

---

### Collections

`src/api/collections_api.rb`. Full CRUD, plus a membership-scoped `LIST`:

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/collections` | List, filtered to collections the caller's account is a member of, **plus** any collection that is the `one_off_collection` of a `CollectionGroup` the caller belongs to (`one_off_collections_granted_by_boards` — a board's one-off scratch collection carries no roster of its own; access is derived from the board). Non-deleted only. |
| `GET` | `/api/collections/:id` | Get (supports `?since=`) — **not** membership-filtered |
| `POST` | `/api/collections` | Create |
| `PUT` | `/api/collections/:id` | Update |
| `DELETE` | `/api/collections/:id` | Delete |
| `GET` | `/api/collections/:collectionId/listItems` | All items across all lists in the collection (deduped, recursively includes group members via `children`). Supports `?since=`. |
| `DELETE` | `/api/collections/:collectionId/actions/:actionId` | Cascade-remove an action from the collection, all its lists, and all `collection.groups[].actions`. `404` if collection missing, `400` if action not on the collection. |
| `DELETE` | `/api/collections/:collectionId/templates/:templateId` | Cascade-remove a template: clears `list.template` on any list using it and strips the template from every item in that list, then removes it from `collection.templates`. |
| `DELETE` | `/api/collections/:collectionId/tags/:tagId` | Cascade-remove a tag from every `Item` in every list of the collection, including items nested inside `ItemGroup.group`, then from `collection.tags`. |

When `current_account_id` is `nil` (auth skipped: e2e, or an unauthenticated internal caller), `members_only` returns records unfiltered — the open path is not reachable in production, since `protected!` always names a real account there.

See [Collection shape](#collection-shape).

---

### Lists

`src/api/lists_api.rb`. Full CRUD plus:

| Method | Path | Description |
|---|---|---|
| `GET` / `POST` / `PUT` / `DELETE` | `/api/lists[/:id]` | Standard CRUD |
| `PUT` | `/api/lists/:id` | Same as update, **plus**: if the list had a `template` and the update clears it, the template is stripped from every item currently in the list. |
| `GET` | `/api/lists/:listId/items` | All items in the list, recursively including `Item.children` and `ItemGroup.group` members. Supports `?since=`. `404` if the list itself doesn't exist. |
| `POST` | `/api/lists/:listId/items` | Create an item and add it to the list. Body: item fields; optional `"id"` (`400` if it already exists). Dispatches to `ItemGroup` if the body has a `"group"` key, else `Item`. Applies the list's `template` if set. Returns `201` + created item (raw `item.json`, not `to_schema_object`). |
| `PUT` | `/api/lists/:listId/items/:itemId` | Merge fields into an existing item; ensures the list's template is applied first if missing; validates; saves. Returns `200` + `to_schema_object`. |
| `PUT` | `/api/lists/:listId/addItem/:itemId` | Add an existing item to the list (applies template ref if set). `200`, no body. |
| `PUT` | `/api/lists/:listId/removeItem/:itemId` | Remove an item from the list (strips template ref if set). `200`, no body. |
| `POST` | `/api/lists/:listId/actions` | Create an `Action` and attach it to the list. Returns `201` + the **list** object (not the action). |

See [List shape](#list-shape).

---

### Items

`src/api/items_api.rb`. Standard CRUD (`generate_schema_crud_methods 'items', Item`) plus the status transition front door and cross-collection search:

| Method | Path | Description |
|---|---|---|
| `GET` / `POST` / `PUT` / `DELETE` | `/api/items[/:id]` | Standard CRUD |
| `POST` | `/api/items/:id/status` | Server-authoritative status change. Body: `{ "status": "doing" }`. Delegates to `set_status(item_id, status, actor_id)` (`actor_id` = `current_account_id`) — server owns `from`, appends a stamped `Transition` to `item.transitions`, then saves. Flipping to `doing` also opens/stamps a run-keeping instance if the item's template opts in — see [Instances](#instances-repeat-engagement). Returns `200` + updated item. `400` if `status` isn't one of `Status::VALUES`; `404` if item missing. |
| `GET` | `/api/items/query` | Cross-collection item search. `?q=<query>` (required, URL-encoded) in the [Query language](#query-language). Returns `200` + `{ count, groups: [...] }` grouped by collection. No matches is an empty `200`, never a `404`. `400` (naming the position, unknown field, or valid enum values) for a malformed query or missing `q`. |

**Route order matters:** `/api/items/query` is declared *above* `generate_schema_crud_methods` in `items_api.rb`, so it isn't swallowed by the generated `GET /api/items/:id` as a lookup for id `"query"`.

`owner` (an account id, or absent = unowned) is a plain schema field written through ordinary CRUD — no dedicated endpoint. `PUT` validates it names a real `Account` (`400 Unknown owner '<id>'` otherwise).

Item placement/occurrence sub-resources are under `/api/items/:id/placements` and `/api/items/:id/occurrences` — see [Placements](#placements) and [Occurrences](#occurrences). The legacy `/api/items/:item/dates` route lives under [Dates — legacy](#dates-legacy-dormant).

See [Item shape](#item-shape), [Instances](#instances-repeat-engagement), [Status & Transition shape](#status--transition-shape), [Query language](#query-language).

---

### Item Groups

`src/api/item_groups_api.rb`. Full CRUD (`generate_schema_crud_methods 'itemGroups', ItemGroup`) plus:

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/itemGroups/forMembers?ids=a,b,c` | The groups claiming any of those item ids — the member → group lookup, which the schema has no back-pointer for. `[]` for ids in no group, and for no ids. Declared above the generated CRUD so Sinatra doesn't parse `forMembers` as a `:id`. `200`. |
| `PUT` | `/api/itemGroups/:groupId/addItem/:itemId` | `itemId` must be an existing `Item`. Appends to `group`. `200`. |
| `PUT` | `/api/itemGroups/:groupId/removeItem/:itemId` | Refuses if it's the last remaining member (groups require ≥1 item). `200`. |

**Bug:** both guard clauses (`src/api/item_groups_api.rb:26` and `:34`) use `throw ListError::BadRequest, "..."` instead of `raise`. Nothing in the app `catch`es that tag, so Sinatra's catch-all `error do` block handles it and returns **`500`** ("Internal Server Error" — an uncaught throw), not the intended `400`.

See [ItemGroup shape](#itemgroup-shape).

---

### Templates

`src/api/templates_api.rb`. Full CRUD only (`generate_schema_crud_methods 'templates', Template`). The built-in `todo` template (`id`/`key` = `"todo"`, fields `todo-date` (Date) and `completed` (Boolean)) is created at server startup in `BaseApi.start` if it doesn't already exist.

Write-time validation (`Template#validate`, `src/type/template.rb`):
- Refuses a field keyed to a reserved system key (`ReservedFields::SYSTEM_KEYS` minus the few a template legitimately owns) — `400 Validation Exception` naming the key.
- If this template is named as another template's instance-record child (`attributes.instances.template`, see [Instances](#instances-repeat-engagement)), refuses to drop the `finished` field the ledger counts by.

The opt-in that turns a template into a repeat-engagement tracker (`attributes.instances`) is written only through `POST /api/actions/ad-hoc/enableInstances` (see [Instances](#instances-repeat-engagement)) — never directly via `PUT /api/templates/:id`, though nothing at the route level blocks it.

See [Template and Field shape](#template-and-field-shape).

---

### Tags

`src/api/tags_api.rb`. Full CRUD only (`generate_schema_crud_methods 'tags', Tag`).

See [Tag shape](#tag-shape).

---

### Actions

`src/api/actions_api.rb`. Named, reusable step sequences over items, executable by id or ad hoc.

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/actions/types` | **Must be registered before the CRUD routes** (a literal-path guard so `types` isn't parsed as an action id). Returns the full `action_methods` registry (see below). |
| `GET` / `POST` / `PUT` / `DELETE` | `/api/actions[/:id]` | Standard CRUD |
| `POST` | `/api/actions/:action_id` | Runs every step of a saved action. Body: params the steps need; merged with `actor_id` = the caller's account (`with_actor`), then over each step's `fixed_params`; `dynamic_params` can pull a prior step's result field in. `200`, no body. `404` if action not found. |
| `POST` | `/api/actions/ad-hoc/:action_type` | Builds a throwaway one-step action of type `action_type` and executes it immediately with the request body (plus `actor_id`) as params. `200`, no body. |

`actor_id` is always written from the request (even as `nil`), so neither a saved action's `fixed_params` nor the request body can name someone else as the author of a status/placement change.

#### `GET /api/actions/types` response (current registry — `src/actions/item_actions.rb`)

```json
{
  "moveItem":                { "method": "move_item",                "params": ["item_id", "from_list", "to_list"] },
  "copyItem":                 { "method": "copy_item",                 "params": ["item_id", "to_list"] },
  "duplicateItem":            { "method": "duplicate_item",            "params": ["item_id", "to_list"] },
  "removeItem":               { "method": "remove_item",               "params": ["item_id", "from_list", "item_index"] },
  "promoteGroupItem":         { "method": "promote_group_item",        "params": ["item_id", "from_list", "item_index"] },
  "setField":                 { "method": "set_field",                 "params": ["item_id", "key", "value"] },
  "addItemToField":           { "method": "add_item_to_field",         "params": ["item_id", "key", "value"] },
  "setStatus":                { "method": "set_status",                "params": ["item_id", "status", "actor_id"] },
  "assignToDate":             { "method": "assign_to_date",            "params": ["item_id", "date", "collection_id", "actor_id"] },
  "removeFromDate":           { "method": "remove_from_date",          "params": ["item_id", "date", "collection_id"] },
  "setPlacementPriority":     { "method": "set_placement_priority",    "params": ["item_id", "date", "collection_id", "priority"] },
  "createFloatingPlacement":  { "method": "create_floating_placement", "params": ["item_id", "collection_id", "staged_week", "actor_id"] },
  "bindPlacement":            { "method": "bind_placement",            "params": ["placement_id", "date"] },
  "updatePlacement":          { "method": "update_placement",          "params": ["placement_id", "fields", "actor_id"] },
  "deferPlacement":           { "method": "defer_placement",           "params": ["placement_id", "week_start"] },
  "refloatPlacement":         { "method": "refloat_placement",         "params": ["placement_id", "week_start"] },
  "deletePlacement":          { "method": "delete_placement",          "params": ["placement_id"] },
  "createInstance":           { "method": "create_instance",           "params": ["item_id", "fields"] },
  "closeInstance":            { "method": "close_instance",            "params": ["instance_id", "finished_date", "actor_id"] },
  "deleteInstance":           { "method": "delete_instance",           "params": ["instance_id", "actor_id"] },
  "enableInstances":          { "method": "enable_instances",          "params": ["parent_template_id", "child_template_id"] }
}
```

`materialize_occurrence` and `reconcile` are **not** in this registry — invoked only via their own dedicated REST routes (`POST /api/items/:id/occurrences`, `POST /api/reconcile`), not composable into ad-hoc/saved actions.

See [Action Step Types](#7-action-step-types) for the full behavior of each entry, and [Instances](#instances-repeat-engagement) for the four instance-lifecycle entries.

---

### Placements

`src/api/placements_api.rb`. The current model for "where/when an item sits" — a `Placement` references a catalog item by id (never copies it) and represents either a dated instance (on a specific day) or a floating instance (dayless, in a staging pile). See [Placement shape](#placement-shape).

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/collections/:id/placements` | Weekly-planning range read for **one** collection: `?start=YYYY-MM-DD&end=YYYY-MM-DD` (both required, `start <= end`). Returns `{ "YYYY-MM-DD": [<placement>, ...] }` — full placement objects (`to_client_object`, which adds `catalog_item_id`). |
| `GET` | `/api/placements` | Same range read across a **set** of collections. `?collections=c1,c2&start=&end=` (all required). Returns **full placement objects**, not bare item ids — the grid addresses a placement by `id` to write `resolution` and reads it back to strike a completed card in place. **Resolved placements are NOT filtered out** — the week's board doubles as the record of what got done. |
| `GET` | `/api/placements/floating` | Cross-collection floating staging pile. `?collections=c1,c2,c3` (required) `&week=YYYY-MM-DD` (the visible week's Monday). **Week-scoped**: returns only placements whose `staged_week == week` and are still open (`resolution` nil); omitting `week` falls back to the unfiltered pile. Each object also carries a derived `one_off` boolean (`true` when the **catalog** item — not a raw instance child — has no shelf/list home). |
| `GET` | `/api/placements/current` | The **catalog's** assignment read: `?collections=c1,c2` (required). Returns `{ "<catalog_item_id>": "<account_id>" }` for every item whose applicable occurrence names somebody. No date window. Rule (`Placement.applicable_assignee`): open placements exist → the soonest that names somebody (floating sorts after every dated one); none, and the item is recurring → nothing (a fresh unclaimed occurrence is coming); none, one-off → the last *resolved* one's assignee. Items no occurrence names are **absent**, not null — they resolve to `item.owner` client-side. |
| `GET` | `/api/collections/:id/placements/floating` | Floating (dayless) placements for **one** collection's staging pile. Full `to_schema_object`s (no `one_off`/`catalog_item_id` merge on this route). |
| `GET` | `/api/items/:id/placements` | All placements referencing this item (reverse lookup). Full `to_client_object`s. |
| `POST` | `/api/items/:id/placements` | Create a placement. Body: `{ "collection": "<id>", "date"?: "YYYY-MM-DD", "staged_week"?: "YYYY-MM-DD" }`. With `date` → dated (`assign_to_date`, idempotent on `(item, date, collection)`). Without → floating (`create_floating_placement`, deduped on `(item, collection)` for open placements; a re-stage **re-stamps** `staged_week`). Both resolve a group id to the member you'd pick up, resolve a repeat-tracked item to its open instance (minting one if needed), and revive a terminal item to `want-to`. Returns `200` + placement. |
| `POST` | `/api/placements/:pid/bind` | Bind a floating placement to a day. Body: `{ "date": "YYYY-MM-DD" }`. Sets `date`, clears `floating`; stamps `origin_date` only if absent. |
| `PATCH` | `/api/placements/:pid` | Edit per-instance fields. Body: any of `{ "note", "time_cost", "resolution", "assignee" }` (other keys ignored). `resolution` is `"completed"`\|`"skipped"`\|`null` (`null` reopens; `400` on an unrecognized value) — stamps `resolved_at` and `resolved_by` server-side when set, clears both on reopen. `resolved_by` defaults to the effective assignee (the value being written in this same call, else the placement's stored one, else `item.owner`), falling back to the caller's own account id only if none of those name anyone. `assignee` is an account id or `null` (clears); `400 Unknown assignee '<id>'` if it names no `Account`. A `"completed"` resolution on an instance-tracked item also starts that instance (stamps its `started` date, moves item + instance to `doing` unless already there/retired). Any non-null resolution can trigger `maybe_auto_archive` on the item afterward. |
| `POST` | `/api/placements/:pid/defer` | Defer a floating placement +1 week. Body: `{ "week_start": "YYYY-MM-DD" }`. Sets `staged_week = week_start + 7 days`. |
| `POST` | `/api/placements/:pid/unbind` | Re-float a dated placement back into staging (dated → floating), the inverse of `/bind`. Body: `{ "week_start": "YYYY-MM-DD" }`. Clears `date`, sets `floating`, sets `staged_week = week_start`. **Clears any `resolution`/`resolved_at`**; **preserves `origin_date`**. |
| `DELETE` | `/api/placements/:pid` | Delete a placement outright (id-addressed — works on floating placements). If the underlying item is a board-born one-off (no shelf home) with no other placements left, the orphan item is deleted too. Returns the deleted placement. |
| `DELETE` | `/api/items/:id/placements` | Remove a **dated** placement. Body: `{ "collection": "<id>", "date": "YYYY-MM-DD" }`. Looks up by `(item, date, collection)`; no-op (returns `{}`) if none found. |
| `POST` | `/api/items/:id/placements/priority` | Flag/unflag a dated placement as a priority. Body: `{ "collection": "<id>", "date": "YYYY-MM-DD", "priority": true|false }`. `404` if no matching dated placement. `400` if flagging would exceed `Placement::MAX_PRIORITIES_PER_DATE` (3) already-flagged placements on that date. |

All of the above are thin front doors over registry-registered primitives in `src/actions/*.rb` (same primitives back the `/api/actions/types` entries above), so any of these behaviors are also reachable via `POST /api/actions/:action_id` or `POST /api/actions/ad-hoc/:action_type`.

---

### Occurrences

`src/api/occurrences_api.rb`. A recurrence rule lives on `item.scheduling.recurrence` (see [Recurrence rule shape](#recurrence-rule-shape)); an untouched occurrence is a computed **ghost** (never persisted) until the user acts on it, at which point it "materializes" into a real `Placement`.

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/occurrences` | Ghost occurrences for a week, across a set of collections. `?collections=c1,c2&week_start=YYYY-MM-DD` (both required). `as_of` defaults to today server-side (not a query param on this route). Returns an array of [ghost occurrence objects](#ghost-occurrence-shape). Only **untouched** occurrences are returned. |
| `POST` | `/api/items/:id/occurrences` | Materialize a ghost into a real `Placement`. Body: `{ "collection": "<id>", "period_start": "<the ghost's due-week, YYYY-MM-DD>", "date"?: "YYYY-MM-DD", "staged_week"?: "YYYY-MM-DD" }`. With `date` → dated straight onto that day; without → floating, staged into `staged_week` (defaults to `period_start`). Idempotent: if a placement already exists for this item with matching `collection_id` and `origin_date == period_start`, that placement is returned (a floating one re-stamps `staged_week`). Returns `200` + the persisted placement. |

Recurrence scope as currently validated (`src/type/recurrence.rb`): `cadence` is `"weekly"` or `"monthly"`; `mode` is `"absolute"` only. Anchor kind is cadence-dependent — weekly: `"floating"` | `"fixed-day"` (`weekday` 0–6, Ruby `Date#wday`, Sun=0); monthly: `"date"` (`day` 1–31, clamped to the month's last day) | `"week-of-month"` (`week` 1–5, 5 clamped to the month's last week). Optional `active` (pause without deleting), `start_date` (phase floor), `end_date` (no occurrences due or carrying past its grid week). Relative cadence and mid-series splitting are not implemented.

---

### Reconcile

`src/api/reconcile_api.rb`. The idempotent "age the board forward" sweep — not registry-registered (no positional item params; a standalone global pass), meant to be called by an external hourly loop and on weekly-planner load.

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/reconcile` | Body optional: `{ "as_of_date"?: "YYYY-MM-DD" }` (defaults to today; malformed/missing body is swallowed to `{}`). Runs `reconcile(as_of_date:)`: **(0) prune** orphaned placements (item deleted); **(1) release** — for anything left over from a week now behind the current one (Monday of `as_of_date`): a floating **shelf-item** placement un-stages (deleted; the item stays on its shelf); a **one-off** left over (floating past its `staged_week`, or dated before the current week) **lapses** (`resolution: 'lapsed'` + `resolved_at`, retained); **(2) auto-archive** — every one-off whose placement set is now fully resolved (explicit completes/skips/lapses — nothing resolves by time alone) sweeps to `status: 'completed'` via `maybe_auto_archive`. Returns `{ "released": [pid...], "lapsed": [pid...], "archived": [item_id...], "pruned": [pid...] }`. |

Structurally idempotent: released rows are gone, a lapsed placement is resolved (so it no longer matches the release scan), and archive is a no-op once terminal.

---

### Dates — LEGACY (dormant)

`src/api/dates_api.rb` + `src/api/helpers/date_helpers.rb`. **These routes still exist in code and are wired up**, implementing the retired parent/child recurring model and the `Day`/`DailyItem` storage shape that `Placement` has superseded for the weekly-planning read paths. Treat this whole section as legacy.

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/dates` / `/api/dates/:id` | Standard list/get of raw `Day` objects — **only** list/get are generated (`generate_schema_endpoint :list/:get, 'dates', Day`); there is no create/update/delete route for `Day` via this macro. Supports `?since=`. |
| `GET` | `/api/dates/:day/:collection/items` | Item ids for one day + collection. `[]` if missing. |
| `GET` | `/api/dates/:collection/items?start=&end=` | Item ids across a date range for one collection → `{ "date": [item_id] }`, dateless entries omitted. Superseded by `GET /api/collections/:id/placements`. |
| `POST` | `/api/dates/:day/items` | Assign an item to a day/collection (creates the `Day` if needed); syncs `todo-date` if the item has the `todo` template. |
| `DELETE` | `/api/dates/:day/items` | Unassign; clears `todo-date` if applicable; deletes the `Day` record if left with no items/priorities. |
| `POST` | `/api/dates/:day/priority` | Add to the day/collection's priority list. `404` if collection missing. |
| `DELETE` | `/api/dates/:day/priorities` | Remove from the priority list. |
| `PUT` | `/api/dates/:day/:collection/priorities` | Replace the entire priority list for a day/collection with a given ordered array of item ids. |
| `POST` | `/api/dates/:day/recurring` | Create a **legacy parent/child** recurring series starting `:day`. Body: `{ "collection", "item", "type", "interval", "end-date"? }`. Only `type: "weekly"` actually generates child items. `400` if the item is already recurring. Adds the `recurring-item` template. |
| `PUT` | `/api/dates/:day/recurring` | Modify an existing legacy series (by parent or child id); can re-date and/or re-anchor the parent to a different item. |
| `DELETE` | `/api/dates/:day/recurring` | Delete legacy series occurrences from `:day` forward (by parent or child id). |
| `GET` | `/api/items/:item/dates` | All dates this item is currently assigned to, per the `Day`-index pstore cache (`Day.get_days_for_item`). |

**Bug:** `PUT /api/dates/:day/:collection/priorities`'s not-found message (`src/api/dates_api.rb:124`) interpolates an empty string instead of the collection id: `"Collection id '#{}' cannot be found"` — should read `params['collection']`.

Legacy item fields written by these routes (`recurring-event`, `recurring-parent`, `recurring-children`) are documented in [Legacy recurring item fields](#legacy-recurring-item-fields); they are **not** part of the `Item` schema's declared fields.

---

## 6. Complex Data Model Shapes

### Collection shape

`src/type/collection.rb`.

```json
{
  "id": "col-abc",
  "key": "my-collection",
  "name": "My Collection",
  "lists": ["list-1", "list-2"],
  "templates": ["template-1"],
  "actions": ["action-1"],
  "tags": ["tag-1"],
  "groups": [
    { "key": "group-a", "name": "Group A", "lists": ["list-1"], "actions": ["action-1"] }
  ],
  "attributes": { "any": "value" },
  "sharing_scope": "private",
  "members": ["account-1", "account-2"],
  "updated_at": "2026-01-01T00:00:00Z"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `key` | `String` | No | |
| `name` | `String` | **Yes** | |
| `lists` | `Array<String>` | No | List ids (type refs) |
| `templates` | `Array<String>` | No | Template ids (type refs) |
| `actions` | `Array<String>` | No | Action ids (type refs) |
| `tags` | `Array<String>` | No | Tag ids (type refs) |
| `groups` | `Array<ListGroup>` | No | **Embedded objects**, not type refs — see below |
| `attributes` | `Hash` | No | Arbitrary metadata |
| `sharing_scope` | `String` | No | `"private"` \| `"shared"` (`SharingScope`). Absent reads as `"private"`. Structural only — no sharing/invite UI reads it yet. |
| `members` | `Array<String>` | No | Account ids (type refs) — the single record of who can reach this collection. `GET /api/collections` filters by it; other reads/writes are not membership-checked. |

#### `groups` — ListGroup embedded shape

`src/type/list_group.rb`. Stored inline in `collection.groups`, not by reference:

```json
{ "key": "group-key", "name": "Group Name", "lists": ["list-id-1", "list-id-2"], "actions": ["action-id-1"] }
```

---

### CollectionGroup shape

`src/type/collection_group.rb`. A board: a named, ordered, shared set of collections. Stored (unlike `ListGroup`, which is embedded and has no independent life).

```json
{
  "id": "cg-1",
  "key": "family-board",
  "name": "Family",
  "collections": ["col-abc", "col-def"],
  "members": ["account-1", "account-2"],
  "one_off_collection": "col-ghi",
  "updated_at": "2026-01-01T00:00:00Z"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `key` | `String` | No | |
| `name` | `String` | **Yes** | |
| `collections` | `Array<String>` | No | Collection ids (type refs), ordered — the on-screen order in the planner's pile. Holding the group grants nothing by itself; a member sees only the intersection with their own collection memberships. |
| `members` | `Array<String>` | No | Account ids (type refs). `GET /api/collection-groups` filters by it. |
| `one_off_collection` | `String` | No | Type ref to a `Collection` that holds no members of its own — access to it is derived from group membership (`one_off_collections_granted_by_boards` in `collections_api.rb`), so renaming/sharing the board carries through to it without a second roster to keep in sync. |

---

### List shape

`src/type/list.rb`.

```json
{
  "id": "list-1",
  "name": "My List",
  "items": ["item-1", "item-2"],
  "template": "template-1",
  "actions": ["action-1"],
  "attributes": { "any": "value" },
  "updated_at": "2026-01-01T00:00:00Z"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | `String` | **Yes** | |
| `items` | `Array<String>` | No | Item ids (type refs, ordered) |
| `template` | `String` | No | Single template id (type ref) |
| `actions` | `Array<String>` | No | Action ids (type refs) |
| `attributes` | `Hash` | No | Arbitrary metadata |

A list has no `sharing_scope` or `members`; access is at the collection level.

---

### Item shape

`src/type/item.rb`. Schema-declared fields only (templates may add more):

```json
{
  "id": "item-1",
  "name": "My Item",
  "templates": ["todo"],
  "tags": ["tag-1"],
  "parent": "item-parent-id",
  "children": ["item-child-1"],
  "status": "want-to",
  "transitions": [
    { "from": null, "to": "want-to", "at": "2026-01-01T00:00:00Z" },
    { "from": "want-to", "to": "doing", "at": "2026-01-02T00:00:00Z", "by": "acct_a" }
  ],
  "energy": "chill",
  "scheduling": { "recurrence": null },
  "owner": "acct_a",
  "updated_at": "2026-01-01T00:00:00Z"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | `String` | **Yes** | |
| `templates` | `Array<String>` | No | Template ids, set semantics (no dupes) |
| `tags` | `Array<String>` | No | Tag ids |
| `parent` | `String` | No | Parent item id. Used for a group's plain child item, and for a repeat-tracked item's instance children — see [Instances](#instances-repeat-engagement) |
| `children` | `Array<String>` | No | Child item ids; `GET /api/lists/:listId/items` recursively includes these. For a repeat-tracked item, holds every instance ever minted (open + closed) |
| `status` | `String` | No | See [Status & Transition shape](#status--transition-shape). Defaults to `"want-to"` on creation (`Item#initialize`, not a schema-level default). |
| `transitions` | `Array<Transition>` | No | Append-only; written only by `set_status` |
| `energy` | `String` | No | See [Energy shape](#energy-shape). **Absent means `"moderate"`**, never written as a default. Written through ordinary CRUD. |
| `scheduling` | `Scheduling` (Hash) | No | See [Scheduling shape](#scheduling-shape) |
| `owner` | `String` | No | Account id — whose this usually is. Durable; a placement with no `assignee` resolves to this. `400 Unknown owner '<id>'` if it names no `Account`. |

Any additional fields declared by the item's `templates` (e.g. `todo-date`, `completed` from the built-in `todo` template) are also valid on the item object.

---

### Instances (repeat engagement)

Repeat engagement with a catalog item (replaying a game, rewatching a film). An **instance** is one complete engagement, modeled as a plain child `Item` (`item.parent` → the catalog item, `item.children` on the parent lists every instance) rather than a new type, so it keeps templates, custom fields and its own status/lifecycle for free. Its sessions are ordinary `Placement`s pointing at the child.

**Opt-in** (`src/actions/enable_instances.rb`, `POST /api/actions/ad-hoc/enableInstances`, body `{ "parent_template_id", "child_template_id" }`): stamps `parent_template.attributes.instances = { "template" => child_template_id }`. Guarantees the child template has the `finished` field (`ReservedFields::INSTANCE_CONTRACT`), adding it if missing. Capped at two layers (a template cannot be both a parent and a child of the instances relationship). `child_template_id` omitted/empty disables tracking (existing instances are untouched).

**Minting is automatic**, not a dedicated user action — three doors, each idempotent (at most one *open* instance per item at a time — "open" = not in a terminal `Status`):

| Door | Trigger | Effect |
|---|---|---|
| Stage | `create_floating_placement` / `assign_to_date` (i.e. `POST /api/items/:id/placements`, `POST /api/items/:id/occurrences`) | Mints (or reuses) the open instance, then places *it* — the placement never points at the catalog item directly. Born at `want-to`, no dates. |
| Begin | `PATCH /api/placements/:pid` with `resolution: "completed"` on an instance-tracked item | First completed session stamps the instance's `started` date (to the placement's own date, not today) and moves both instance and catalog item to `doing` (unless already there or retired). |
| Flip by hand | `POST /api/items/:id/status` with `status: "doing"` | Opens/stamps an instance the same way, for a flip that skips the planner entirely. |

**Manual doors** (both server-authoritative, both routed through `set_status` so the journal is honest):

| Action | Route | Effect |
|---|---|---|
| `create_instance` | `POST /api/actions/ad-hoc/createInstance`, body `{ item_id, fields }` | Backfill/correction: mints an instance directly with caller-supplied `fields` (id/parent/templates/children/transitions stripped). `status` becomes `"completed"` automatically if `fields.finished` is set. `400` if the item's template doesn't track instances. |
| `close_instance` | `POST /api/actions/ad-hoc/closeInstance`, body `{ instance_id, finished_date, actor_id }` | "I finished it": stamps `finished` (defaults to today), backfills `started` from it if absent, moves both instance and parent to `completed`. Distinct from completing a session — one instance can span many completed placements. |
| `delete_instance` | `POST /api/actions/ad-hoc/deleteInstance`, body `{ instance_id, actor_id }` | Undo a run that should never have existed: unlinks it from `parent.children`, soft-deletes it, and reverts the parent's status if it was `doing` solely because of this run (checked via the parent's last transition) and no other instance is open. Placements pointing at the deleted run are left for `reconcile` to prune. |

`item_has_shelf_home?` / auto-archive / `reconcile` all treat an instance (any item with `parent` set) as never board-born and never lapsing on its own — see `src/actions/auto_archive.rb`.

---

### Scheduling shape

`src/type/scheduling.rb`. Holds only the recurrence rule; the item's planning-kind concept (`event`/`task`) was removed from this object — see [Recurrence rule shape](#recurrence-rule-shape) for what "past" means today (a placement's own `resolution`, never derived from the calendar).

```json
{ "recurrence": null }
```
```json
{
  "recurrence": {
    "cadence": "weekly",
    "interval": 2,
    "mode": "absolute",
    "anchor": { "kind": "fixed-day", "weekday": 1 },
    "collection_id": "col-abc",
    "active": true,
    "start_date": "2026-07-27"
  }
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `recurrence` | `Recurrence` (Hash) | No | See below. Absent/`null` = not recurring. An empty `{}` scheduling object (no `recurrence` key) is valid and inert. |

### Recurrence rule shape

`src/type/recurrence.rb`. Lives at `item.scheduling.recurrence`.

```json
{
  "cadence": "monthly",
  "interval": 1,
  "mode": "absolute",
  "anchor": { "kind": "date", "day": 15 },
  "collection_id": "col-abc",
  "active": true,
  "start_date": "2026-07-27",
  "end_date": "2026-12-31"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `cadence` | `String` | **Yes** | `"weekly"` or `"monthly"` (`Recurrence::CADENCES`). |
| `interval` | `Integer` | **Yes** | Positive; cadence-relative — weeks under `weekly`, months under `monthly`. |
| `mode` | `String` | **Yes** | Only `"absolute"` is valid (`Recurrence::MODES`). |
| `anchor` | `Hash` | **Yes** | Cadence-dependent kind — see table below. |
| `collection_id` | `String` | **Yes** | Non-empty; whose staging the occurrence drains into. |
| `active` | `Boolean` | No | Absent = active. `false` pauses the rule (no ghosts emitted) without deleting it. |
| `start_date` | `String` | No | `YYYY-MM-DD`. Phase anchor / floor — a rule doesn't retroactively surface an occurrence dated before this. Absent, phasing falls back to "today" at read time. |
| `end_date` | `String` | No | `YYYY-MM-DD`. No occurrence is due, or carries, past the grid week containing this date — "clear the future"; past placements remain as history. |

**Anchor kinds by cadence** (`Recurrence::ANCHOR_KINDS_BY_CADENCE`):

| Cadence | `anchor.kind` | Extra fields | Meaning |
|---|---|---|---|
| `weekly` | `"floating"` | _(none)_ | Lands dayless in the due week; you pick the day. |
| `weekly` | `"fixed-day"` | `weekday` (0–6, Ruby `Date#wday`, Sun=0) | Pinned to a weekday inside the due week. |
| `monthly` | `"date"` | `day` (1–31) | Pinned to a day of the month; an overflowing day clamps to the month's last (the 31st lands on Feb 28). |
| `monthly` | `"week-of-month"` | `week` (1–5) | Dayless, pinned to a week of the month; 5 always clamps to the month's last week. |

Validated as a whole by `Recurrence.type_match?` — an invalid rule fails item validation (`400 Validation Exception`) rather than partially saving.

### Status & Transition shape

`src/type/status.rb`.

| `Status` value | Meaning |
|---|---|
| `want-to` | Default on creation |
| `doing` | |
| `on-hold` | |
| `completed` | Terminal |
| `retired` | Terminal |

`Status::TERMINAL = ["completed", "retired"]` — "done" is a derived predicate (`Status.done?`), not its own stored value.

A `Transition` entry (in `item.transitions`, append-only, written only by `set_status`):

```json
{ "from": "want-to", "to": "doing", "at": "2026-01-02T00:00:00Z", "by": "acct_a" }
```

| Field | Type | Notes |
|---|---|---|
| `from` | `String` or `null` | Previous status |
| `to` | `String` | Must be a valid `Status` value |
| `at` | `String` | Server-stamped ISO 8601 timestamp; a client cannot supply this |
| `by` | `String` | Absent (never `null`) when nobody acted — `reconcile`'s auto-archive, the unauthenticated e2e path, or an entry written before this field existed. The account whose request made the change, not the placement's `resolved_by`. |

---

### Energy shape

`src/type/energy.rb`. The catalog item's "how much does this demand of me?" axis.

| `Energy` value | Meaning |
|---|---|
| `chill` | Low demand |
| `moderate` | Baseline; **the default, and never persisted** |
| `intense` | High demand / dread |

- **Absent = `moderate`.** `Item#initialize` does not stamp a default, so an unrated item stores no `energy` key. Read it through `Energy.of` / `Energy.of_item`.
- **No server-authoritative setter** — written through ordinary `PUT /api/items/:id`, which **merges**: omitting `energy` preserves the stored value; clearing a rating requires an explicit `"energy": null`.

An unknown tier fails schema validation and the write is rejected.

---

### Query language

`src/query/` — `parser.rb` (lexer + recursive-descent parser), `evaluator.rb` (AST → boolean over one item), `search.rb` (`CatalogIndex` + `Search`). Backs `GET /api/items/query`.

**Fields** (`Query::Parser::FIELDS`) — all item-scoped. The older `item.` prefix (`item.status`) still parses and is normalized away.

| Field | Values |
|---|---|
| `name` | The item name |
| `status` | `want-to` / `doing` / `on-hold` / `completed` / `retired`. Absent reads as `want-to` |
| `energy` | `chill` / `moderate` / `intense`. **Absent reads as `moderate`**, so `energy = moderate` returns every unrated item |
| `tag` | Tag **name**, not id — matching by name makes `tag = Me` one cross-collection question |
| `collection` | Collection name |
| `list` | List name |

**Operators**

| Operator | Meaning |
|---|---|
| `=` / `!=` | Equal / not equal, case-insensitive |
| `~` / `!~` | Contains / does not contain, case-insensitive |
| `IN (a, b)` / `NOT IN (a, b)` | Any of / none of |
| `IS EMPTY` / `IS NOT EMPTY` | Field has no values at all (e.g. `tag IS EMPTY` finds untagged items) |

**Booleans:** `AND`, `OR`, `NOT`, `( )` to arbitrary depth. Precedence `NOT` > `AND` > `OR` (SQL-like) — `a OR b AND c` means `a OR (b AND c)`.

**Values:** bare words matching `[\w\-./]+`; quoted (single or double) for values with spaces or that would otherwise lex as a keyword.

**Keywords, field names, and value comparisons are all case-insensitive.**

```
energy = chill AND status != completed
tag = "Me" AND (energy = chill OR name ~ paint)
status IN (want-to, doing) AND collection = Home
NOT (status = completed OR status = retired) AND tag IS EMPTY
```

**Multi-valued fields:** `tag`, `collection`, `list` can each hold several values — every field resolves to a list internally. `=` asks "does *any* value match"; `!=` is its exact negation ("does *no* value match"), so `tag != Me` means "not assigned to me". `IS EMPTY` exists because a field with no values already fails `=` and passes `!=`.

**Errors are loud on purpose** — an unknown field, unparseable expression, or invalid enum value (`status = doig`) is a `400` naming the problem, never a silent empty result.

**Known limits:**
- Items with no list home (a board-born one-off) are not reachable — the index walks collections → lists → items.
- Template-defined custom fields are not queryable; only the universal spine and location are.
- No sorting or paging: results are grouped by collection, each group's items sorted by name.
- `src/filter/filter.rb` is a superseded earlier attempt (regex splitting, single-level parens, no `NOT`, left-to-right AND/OR fold). Unreferenced by any route.

---

### Placement shape

`src/type/placement.rb`. A Placement references a catalog `Item` by id (never a copy) — one item can have many placements.

```json
{
  "id": "pl-1",
  "item_id": "item-1",
  "collection_id": "col-abc",
  "date": "2026-07-30",
  "floating": false,
  "priority": false,
  "resolution": null,
  "resolved_at": null,
  "resolved_by": null,
  "origin_date": "2026-07-28",
  "not_before": null,
  "staged_week": null,
  "time_cost": 30,
  "note": "carried from Tuesday",
  "assignee": "acct_a",
  "updated_at": "2026-07-30T00:00:00Z"
}
```

`to_client_object` (the shape every read above returns) adds one derived field:

| Field | Type | Notes |
|---|---|---|
| `catalog_item_id` | `String` | `item_id` if `item_id` names an item with no `parent`; otherwise that item's `parent` (an instance's placement is addressed to the instance, but a card renders as the catalog item). |

| Stored field | Type | Required | Notes |
|---|---|---|---|
| `item_id` | `String` | **Yes** | Type ref to `Item` |
| `collection_id` | `String` | **Yes** | Type ref to `Collection` |
| `date` | `String` (Date) | No | `YYYY-MM-DD`. `nil` when floating. |
| `floating` | `Boolean` | No | `true` = dayless, in staging; a date + `floating` false = dated. One flag, one entity — binding just sets `date` and clears this. |
| `priority` | `Boolean` | No | A flagged **dated** placement. Capped at `Placement::MAX_PRIORITIES_PER_DATE` (3) per date, enforced in `set_placement_priority`. |
| `resolution` | `String` | No | `"completed"` \| `"skipped"` \| `"lapsed"` (`Resolution::VALUES`). **Absent = open** — no default/sentinel. `Placement#resolved?` is just `!resolution.nil?`; nothing resolves by the passage of time alone. |
| `resolved_at` | `String` | No | Server-stamped ISO 8601 when `resolution` is set; cleared on reopen. |
| `resolved_by` | `String` | No | Account id that closed this — the *plan's* answer (assignee override, else the item's owner), falling back to the request's actor only if neither names anyone. Absent on rows resolved before this field existed or with no account header. |
| `origin_date` | `String` (Date) | No | The **original** date this placement was first bound to. Immutable once set — never overwritten by a later carry-forward re-float. Also the recurrence "due-week" anchor when materialized from a ghost (`origin_date == period_start`). |
| `not_before` | `String` (Date) | No | **Vestigial**: `staged_week` is the single week anchor now; nothing writes `not_before` anymore. Kept so old rows validate. |
| `staged_week` | `String` (Date) | No | The week (Monday, `YYYY-MM-DD`) a **floating** placement is staged into. The pile reads only `staged_week == the visible week`; `reconcile` releases anything behind the current week. Irrelevant once dated. |
| `time_cost` | `Integer` | No | Per-instance actual time cost |
| `note` | `String` | No | Per-instance note |
| `assignee` | `String` | No | Account id doing this **occurrence** — independent of `item.owner`, per-instance so an alternating chore doesn't overwrite whose turn it was. `400 Unknown assignee '<id>'` if it names no `Account`. Restricts nothing (display/planning only). |

### Resolution shape

`src/type/resolution.rb`. `Resolution::VALUES = ["completed", "skipped", "lapsed"]`. Absent/`nil` = open; there is no default value. `lapsed` is written only by `reconcile`, never by a client directly (`update_placement` accepts it as a value but nothing in the UI flow sends it) — distinct from a deliberate `skipped`.

---

### Ghost occurrence shape

Returned only by `GET /api/occurrences` (`build_ghost` in `src/actions/occurrences.rb`). **Never persisted** — computed fresh per request, shaped to resemble a Placement so the client can merge it into the same view, plus ghost-specific provenance.

```json
{
  "ghost": true,
  "rule_item_id": "item-1",
  "item_id": "item-1",
  "collection_id": "col-abc",
  "date": "2026-08-03",
  "floating": false,
  "origin_date": "2026-08-03",
  "period_start": "2026-08-03",
  "carried": false
}
```

| Field | Type | Notes |
|---|---|---|
| `ghost` | `Boolean` | Always `true` — the client's discriminator vs. a real placement (which has no `ghost` key and does have an `id`). |
| `rule_item_id` / `item_id` | `String` | Both present and equal — the catalog item carrying the recurrence rule. |
| `collection_id` | `String` | From `recurrence.collection_id`. |
| `date` | `String` or `null` | Set only for a **pinned, non-carried** occurrence (weekly `fixed-day`, or monthly `date`). `null` for a dayless anchor (`floating`, `week-of-month`), and for **any carried** occurrence — a slipped pinned occurrence re-floats. |
| `floating` | `Boolean` | `true` when `date` is `null`. |
| `origin_date` | `String` | For a pinned, non-carried occurrence: the actual pinned date. Otherwise: the due-week's first day. Becomes the materialized placement's `origin_date` verbatim. |
| `period_start` | `String` | The rule's due-week — echo this back as `period_start` when materializing. |
| `carried` | `Boolean` | `true` if the occurrence's due-week is strictly before the requested week (it's riding forward, untouched). Carry never projects into the *future* relative to `as_of` — a week later than today shows a ghost only in the week it's actually due. |

Only one ghost per rule is ever live at a time (the most recent due-week at or before the requested week); older due-weeks auto-expire without surfacing. A ghost stops appearing the instant its occurrence is materialized. A rule whose `anchor` shape this server version doesn't recognize (e.g. left behind by a future rename) yields no ghost for that rule rather than raising — one bad rule doesn't take down the whole week's read.

---

### ItemGroup shape

`src/type/item_group.rb`.

```json
{ "id": "group-1", "name": "Optional Group Name", "group": ["item-1", "item-2"], "updated_at": "2026-01-01T00:00:00Z" }
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | `String` | No | |
| `group` | `Array<String>` | **Yes** | Item ids; must have ≥1 entry — removing the last one via the API is blocked (see [bug note](#item-groups) — currently returns `500` instead of the intended `400`). |

Detected at creation time only by the presence of a `"group"` key in the POST body (`ItemGeneric.from_schema_object`) — no explicit type discriminator field. Template add/remove operations on a group propagate to every member `Item`. Staging/dating a group resolves to the member you'd pick up (`doing` wins, else the first `want-to`; on-hold and terminal members are skipped) — `400` if every member is finished, retired, or on hold.

---

### Template and Field shape

`src/type/template.rb`.

```json
{
  "id": "template-1",
  "key": "my-template",
  "display_name": "My Template",
  "fields": [
    { "key": "status", "required": true, "type": "Dropdown", "display_name": "Status", "static_options": ["Todo", "In Progress", "Done"] },
    { "key": "due", "required": false, "type": "Date", "display_name": "Due Date" }
  ],
  "highlight_fields": ["status"],
  "attributes": { "instances": { "template": "playthrough-template-id" } },
  "updated_at": "2026-01-01T00:00:00Z"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `key` | `String` | **Yes** | |
| `display_name` | `String` | **Yes** | |
| `fields` | `Array<Field>` | **Yes** | Accepts raw hashes on write; converted to `Field` objects |
| `highlight_fields` | `Array<String>` | No | Field keys to surface prominently |
| `attributes` | `Hash` | No | `attributes.instances = { "template" => "<child template id>" }` opts this template into repeat-engagement tracking — see [Instances](#instances-repeat-engagement). Only written via `enableInstances`, though nothing at the route level enforces that. |

**Validation** (`Template#validate`): schema validation, then refuses any field keyed to a reserved system key (`ReservedFields::SYSTEM_KEYS`, e.g. `status`, `energy`, `owner`, `parent` — a small set is exempted because legacy templates legitimately declare them, `ReservedFields::TEMPLATE_DECLARABLE`). If this template is some other template's instance-record child, also refuses to drop the `finished` field.

Field types: see [Template Field Types](#8-template-field-types). A template can nest another template as a field's `type`/`subtype`, validated recursively with cycle protection.

---

### Action and ActionStep shape

`src/type/action.rb`.

```json
{
  "id": "action-1",
  "name": "Move to Done",
  "steps": [
    { "type": "moveItem", "fixed_params": { "to_list": "done-list-id" }, "dynamic_params": { "item_id": "someStep.id" }, "input_params": ["item_id", "from_list"] }
  ],
  "inputs": { "item_id": "string" },
  "updated_at": "2026-01-01T00:00:00Z"
}
```

| Action field | Type | Required | Notes |
|---|---|---|---|
| `name` | `String` | **Yes** | |
| `steps` | `Array<ActionStep>` | **Yes** | Executed in order |
| `inputs` | `Hash<String,String>` | No | UI hint |

| ActionStep field | Type | Required | Notes |
|---|---|---|---|
| `type` | `String` | **Yes** | One of the [Action Step Types](#7-action-step-types) keys |
| `fixed_params` | `Hash<String,String>` | **Yes** | Merged over the incoming params (fixed values win) |
| `dynamic_params` | `Hash<String,String>` | No | `paramName => "stepType.field"` — pulls a prior step's result field in |
| `input_params` | `Array<String>` | No | UI hint only |

---

### Tag shape

`src/type/tag.rb`.
```json
{ "id": "tag-1", "key": "important", "name": "Important", "updated_at": "2026-01-01T00:00:00Z" }
```
| Field | Type | Required |
|---|---|---|
| `key` | `String` | No |
| `name` | `String` | No |

### Account shape

`src/type/account.rb`.
```json
{ "id": "account-abc123", "name": "My Account", "attributes": {}, "updated_at": "2026-01-01T00:00:00Z" }
```
| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | `String` | No | |
| `attributes` | `Hash` | No | Deferred prefs home; unread by any route today. |

There is **no** `collections` field on `Account` — that direction was inverted (`Collection.members` names accounts, not the reverse), so identity never depends on content.

---

### Day and DailyItem shape

`src/type/day.rb`. **Legacy but still the live storage type** underlying the [Dates — legacy](#dates-legacy-dormant) routes; `Placement` is the source of truth for the current planning UI.

```json
{
  "id": "2026-06-15",
  "items": [ { "id": "col-abc", "items": ["item-1", "item-2"] } ],
  "priorities": [ { "id": "col-abc", "items": ["item-1"] } ]
}
```

| Day field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | **Yes** | `YYYY-MM-DD` |
| `items` | `Array<DailyItem>` | No | Assigned items grouped by collection |
| `priorities` | `Array<DailyItem>` | No | Priority items grouped by collection |

`DailyItem` (inline, not separately persisted):

| Field | Type | Required |
|---|---|---|
| `id` | `String` (Collection ref) | **Yes** |
| `items` | `Array<String>` | No |

A `Day` record auto-deletes once both `items` and `priorities` are empty. `Day` also maintains a separate pstore-backed reverse index (`item_to_days.pstore`) mapping item id → dates, rebuilt at server start (`Day.build_full_day_index`) and read by the legacy `GET /api/items/:item/dates`.

---

### Legacy recurring item fields

Written directly into an item's raw JSON by the [legacy Dates recurring routes](#dates-legacy-dormant) — not declared in the `Item` schema's field list, so they don't show up in ordinary validation but do round-trip through the JSON store.

On the **parent** item (holds the series definition):

| Field | Type | Notes |
|---|---|---|
| `recurring-event` | Hash | `{ "type": "daily"\|"weekly"\|"monthly"\|"yearly", "interval": Integer, "end-date"?: "YYYY-MM-DD" }`. Only `type: "weekly"` actually generates future child items (`DateHelpers.find_recurring_event_days`); other types are schema-valid via the `RecurringDate` template field type but don't auto-generate. |
| `recurring-children` | `Array<String>` | Ordered child item ids |

On each **child** occurrence item:

| Field | Type | Notes |
|---|---|---|
| `recurring-parent` | `String` | Back-reference to the parent |
| `todo-date` | `String` | Set to that occurrence's date (only synced if the item has the `todo` template) |

Superseded by [Recurrence rule shape](#recurrence-rule-shape) + [Ghost occurrence shape](#ghost-occurrence-shape) in the current model.

---

## 7. Action Step Types

Values for `ActionStep.type`, per `src/actions/item_actions.rb`'s `action_methods` registry (also returned by `GET /api/actions/types`):

| Type | Parameters | Description |
|---|---|---|
| `moveItem` | `item_id`, `from_list`, `to_list` | Moves an item between lists; fails if `from_list` doesn't contain it. |
| `copyItem` | `item_id`, `to_list` | Adds an item to another list without removing it from its current one. |
| `duplicateItem` | `item_id`, `to_list` | Deep-copies an item (new id, same fields); `to_list` optional. |
| `removeItem` | `item_id`, `from_list`, `item_index` | Removes from a list; if `item_index` given, verifies it matches `item_id` first. |
| `promoteGroupItem` | `item_id`, `from_list`, `item_index` | `item_id` = the `ItemGroup` id, `item_index` = the child item id to promote out. Removes the child from the group and lists it directly; collapses/removes the group if it drops to 0–1 members. |
| `setField` | `item_id`, `key`, `value` | Directly sets `item.json[key] = value` on an `Item`; saves immediately. No validation before save on the `set_field` path (contrast `addItemToField`, which validates). |
| `addItemToField` | `item_id`, `key`, `value` | Appends to `item.json[key]` (array; created if absent); validates after. |
| `setStatus` | `item_id`, `status`, `actor_id` | Server-authoritative status transition; same primitive as `POST /api/items/:id/status`. May open/stamp a repeat instance — see [Instances](#instances-repeat-engagement). |
| `assignToDate` | `item_id`, `date`, `collection_id`, `actor_id` | Create a dated `Placement`; same primitive as `POST /api/items/:id/placements` (with `date`). |
| `removeFromDate` | `item_id`, `date`, `collection_id` | Delete a dated `Placement`; same primitive as `DELETE /api/items/:id/placements`. |
| `setPlacementPriority` | `item_id`, `date`, `collection_id`, `priority` | Flag/unflag a dated placement; same primitive as `POST /api/items/:id/placements/priority`. |
| `createFloatingPlacement` | `item_id`, `collection_id`, `staged_week`, `actor_id` | Create a floating `Placement`; same primitive as `POST /api/items/:id/placements` (no `date`). |
| `bindPlacement` | `placement_id`, `date` | Bind a floating placement to a day; same primitive as `POST /api/placements/:pid/bind`. |
| `updatePlacement` | `placement_id`, `fields`, `actor_id` | Edit `note`/`time_cost`/`resolution`/`assignee`; same primitive as `PATCH /api/placements/:pid`. |
| `deferPlacement` | `placement_id`, `week_start` | +1 week defer; same primitive as `POST /api/placements/:pid/defer`. |
| `refloatPlacement` | `placement_id`, `week_start` | Dated → floating; same primitive as `POST /api/placements/:pid/unbind`. |
| `deletePlacement` | `placement_id` | Delete a placement (and orphan one-off item if applicable); same primitive as `DELETE /api/placements/:pid`. |
| `createInstance` | `item_id`, `fields` | Backfill/correction: mint a repeat-engagement instance directly. See [Instances](#instances-repeat-engagement). |
| `closeInstance` | `instance_id`, `finished_date`, `actor_id` | "I finished it" — close a run. See [Instances](#instances-repeat-engagement). |
| `deleteInstance` | `instance_id`, `actor_id` | Undo a run that never happened. See [Instances](#instances-repeat-engagement). |
| `enableInstances` | `parent_template_id`, `child_template_id` | Opt a template into (or out of) repeat-engagement tracking. See [Instances](#instances-repeat-engagement). |

`materialize_occurrence` and `reconcile` exist as primitives but are **not** in this registry — REST-only (see [Occurrences](#occurrences) / [Reconcile](#reconcile)).

---

## 8. Template Field Types

`template.fields[].type` values (schema DSL type class names):

| Type string | Accepts | Notes |
|---|---|---|
| `String` | Any string | |
| `Integer` | Integer or numeric string | Coerced during validation. `src/type/template_types/integer_patch.rb` reopens Ruby's core `Integer` class to add the schema DSL hooks (`field_def_validation`/`field_value_validation`/`type_match?`), so the hooks apply to every `Integer` in the process. |
| `Boolean` | `true`/`false` | |
| `Date` | ISO date string | |
| `Array` | Array | Requires a `subtype` |
| `Hash` | Object/map | |
| `Dropdown` | String or Integer | Requires `static_options: [...]` **or** `list_options: "<list-id>"` (mutually exclusive); validates membership. |
| `WeekDays` | Array of day abbreviations | `M`, `T`, `W`, `TH`, `F`, `SA`, `SU` (case-insensitive). |
| `RecurringDate` | Hash | Legacy field type — used by the parent/child recurring model, not the current `Recurrence` rule. Requires `interval` (Integer) and `type` (one of `daily/weekly/monthly/yearly`); optional `end-date` (`YYYY-MM-DD`). Can only be used as a field type, not as an `Array`/`Hash` subtype. |

```json
{ "key": "status", "type": "Dropdown", "static_options": ["Todo", "Done"] }
{ "key": "assignee", "type": "Dropdown", "list_options": "<list-id>" }
```

When `list_options` is used, valid values are the item ids currently in that list.

---

## 9. Sub-Resource and Cascade Patterns

| Operation | Cascades to |
|---|---|
| `DELETE /api/collections/:id/templates/:templateId` | Clears `list.template` on lists using it; strips the template from every item in those lists |
| `DELETE /api/collections/:id/actions/:actionId` | Removes the action ref from all lists and all `collection.groups[].actions` |
| `DELETE /api/collections/:id/tags/:tagId` | Removes the tag from all items and group-member items in all lists |
| `PUT /api/lists/:id` (clears `template`) | Removes the old template from all items currently in the list |
| `PUT /api/lists/:listId/addItem/:itemId` | Applies `list.template` to the item if set |
| `PUT /api/lists/:listId/removeItem/:itemId` | Removes `list.template` from the item if set |
| `POST /api/lists/:listId/items` | Applies `list.template` to the new item if set |
| `ItemGroup` template add/remove | Propagates to every member `Item` |
| `enableInstances` (setting a child template) | Adds the `finished` field to the child template if it's missing |
| `deleteInstance` | Unlinks from `parent.children`; may revert the parent's status |
| `PATCH /api/placements/:pid` (resolution → `"completed"`) | Runs `start_instance_for` if the item is instance-tracked; may run `maybe_auto_archive` |
| `DELETE /api/placements/:pid` | Deletes the orphan one-off item too, if it has no shelf home and no other placements |
| `POST /api/reconcile` | Un-stages past shelf-item placements, lapses past one-offs, sweeps auto-archive across every item with a placement, prunes orphaned placements |
| `DELETE /api/dates/:day/recurring` (legacy) | Deletes all child occurrence items and their day assignments from the given index forward |
| `PUT /api/dates/:day/recurring` (legacy, with child id) | Deletes sibling children from that index onward; promotes the child to be the new series parent |

### Nested delete path pattern

```
DELETE /api/{type}/{objectId}/{subType}/{subObjectId}
```
e.g. `DELETE /api/collections/{id}/templates/{templateId}`, `.../actions/{actionId}`, `.../tags/{tagId}`.

### Id-addressed vs. item-addressed placement mutation

Two addressing schemes coexist for placements:

- **Id-addressed** (`/api/placements/:pid/*`) — works on any placement, dated or floating. Use for bind/unbind/defer/update/delete once you have the placement's own id.
- **Item-addressed** (`/api/items/:id/placements*`) — keyed by `(item, date, collection)`, so it only ever finds a **dated** placement. Use for the initial create, and for deleting/flagging a placement you only know by its item + date.
