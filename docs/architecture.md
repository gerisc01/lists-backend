# Architecture

## Request Lifecycle

```
api.rb
  └── BaseApi.start(port:)        # creates todo template, mirrors cache env, rebuilds day index
  └── Api.run!                    # starts Puma/Sinatra

Incoming request
  └── before hook (base_api.rb)   # CORS preflight passthrough; auth check (protected!)
  └── route dispatch
      ├── *_api.rb                # thin module: calls generate_schema_crud_methods + custom routes
      │   └── list_api_framework.rb   # generates GET/POST/PUT/DELETE/:id + LIST handlers
      │       └── ListApiUtils        # schema_endpoint_* helpers: parse → validate → save → serialize
      └── exception handler (exceptions_api.rb)  # maps ListError subclasses → HTTP status codes
```

## Schema System

Every domain type follows the same pattern:

```ruby
class Item
  schema = Schema.new
  schema.key = "item"           # used as filename prefix in storage
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    { key: 'name', required: true, type: String },
    { key: 'templates', type: Array, subtype: Template, type_ref: true, set: true },
    ...
  ]
  apply_schema schema            # generates all methods
end
```

`apply_schema` generates:
- Instance: `initialize(json?)`, `validate`, `from_object`, `to_object`, `merge!`, field accessors
- Class: `get(id)`, `list(opts?)`, `exist?(id)`, `save!(instance)`, `delete!(id)` — plus `save!` and `delete!` as instance methods

Field types of note:
- `type_ref: true` — stored as ID only; accepts full object on write (auto-creates it)
- `set: true` — array field that enforces uniqueness
- `subtype:` — type of each element in an Array field
- Custom validators in `src/type/template_types/` (Dropdown, WeekDays, RecurringDate, IntegerPatch)

## Template System

Templates define additional fields that can be applied to Lists or Items. When a template is applied, `Item#validate` calls `template.validate_obj(item)` to enforce those fields. This means:

- A template can be added or removed from an item at any time via `templates` array (type_ref)
- Validation only runs on `save!` — stale items with removed template fields are invalid on next save
- The `todo` template (fields: `todo-date`, `completed`) is auto-created at startup and is the default
- Templates can contain nested sub-templates; validation recurses

## Day Cache

The Day cache is a PStore reverse index: `item_id → [ISO date strings]`. It exists for performance — querying "what items appear on date X" without it would require scanning all Day records.

Key behaviors:
- Built fresh on every `BaseApi.start` call via `Day.build_full_day_index`
- Not updated incrementally; must be rebuilt after bulk data changes
- Has its own environment toggle (`Day.toggle_cache_source(:test | :e2e | :scenario)`) that must match the TypeStorage environment
- Location: `cache/item_to_days.pstore` (prod), `cache/item_to_days-test.pstore` (test), etc.

## Storage Layer

`TypeStorage.global_storage` returns a `SchemaTypeStorage` instance pointed at one of four directories. It is a singleton — set once on first access, never changed within a process.

`SchemaTypeStorage` (from `ruby-schema-storage` gem) stores each type as a JSON file: `{dir}/{schema.key}-{id}.json`. It holds an in-memory hash cache and writes through on every `save!`.

## Actions

Actions are multi-step workflows defined as `Action` schema objects. Each step names an action method (registered in `src/actions/item_actions.rb`) and provides params. Steps can reference results from previous steps using a param interpolation syntax. Execution is sequential; any step failure halts the chain.

Available action implementations: `move_item`, `copy_item`, `duplicate_item`, `remove_item`, `promote_group_item`, `set_field`, `add_item_to_field`, `set_status`, `assign_to_date`, `remove_from_date`, `set_placement_priority`, `create_floating_placement`, `bind_placement`, `update_placement`.

Not every primitive is registered in the registry. `maybe_auto_archive` (one-off archive-on-resolve) and `reconcile` (`src/actions/reconcile.rb` — the idempotent carry-forward / past-resolution / auto-archive-of-past pass, keyed off `Placement#resolved?` and the item's `scheduling.type`) are plain functions composed by other actions, not registry-invocable steps. `reconcile` is pure and takes an injectable `as_of_date`; its trigger (an external loop hitting an endpoint + a weekly-planner-load call) is deferred to PR 9b.

## Auth

All endpoints require `ACCOUNT_ID: <token>` header except:
- `POST /api/accounts` — account creation, always open
- All endpoints when `LISTS_BACKEND_E2E_TEST=true` — auth bypassed entirely in the `Api` class `before` hook

Auth validates that the header value matches a persisted Account ID. There are no roles or scopes — any valid account can access any data. Data isolation is not enforced at the API layer.

## Recurring Events

**Two models coexist during the PR 12+ rebuild.** The new rule-based model (below) is being
built to replace the legacy parent-child one; as of PR 13 it is backend-complete but not yet
surfaced (no FE) — so the legacy path stays live but frozen (no new create/edit from the app).

### Rule-based model (new — design §2.5, PR 12+)
A recurrence is a **rule on the catalog item**, folded into `item.scheduling.recurrence`
(validated by `src/type/recurrence.rb`), that keeps **one live occurrence per period**:
- Rule shape: `{cadence, interval, mode, anchor, collection_id, active?, start_date?}`. PR 12
  scope is absolute weekly with `floating` / `fixed-day` anchoring; other cadences/anchors and
  relative mode are deferred.
- Untouched occurrences are **ghosts** — computed for the visible week by
  `occurrences_for_week` (`src/actions/occurrences.rb`, a pure primitive modeled on
  `reconcile`, not registered as an action), never stored. A `Placement` row persists only once
  an occurrence is **touched** (placed/completed/carried/skipped); a persisted placement in a
  period suppresses that week's ghost.
- Invariants: at most one live occurrence per rule per week; an untouched occurrence carries
  forward until the next comes due, then expires.
- Endpoints (PR 13): `GET /api/occurrences?collections=&week_start=` reads the week's ghosts;
  `POST /api/items/:id/occurrences` (body `{collection, period_start, date?}`) is the
  "touch => real" seam — `materialize_occurrence` (`src/actions/materialize_occurrence.rb`,
  REST-only like `reconcile`) persists a ghost as a `Placement` stamped `origin_date =
  period_start`, after which the existing id-addressed `/api/placements/*` endpoints drive it.
  FE cutover (rule editor, ghost surfacing, touch-routing) is still pending (PR 14).

### Legacy parent-child model (frozen, being retired)
- Parent item holds the recurrence spec (`recurring-event` field: `{interval, type, end-date}`) and a `recurring-children` array
- Child items hold a `recurring-parent` reference
- All recurring items are tagged with the `recurring-item` template
- Endpoints: `POST/PUT/DELETE /api/dates/:day/recurring` (dormant — FE no longer calls create/edit)
- `DateHelpers` module in `src/api/helpers/date_helpers.rb` orchestrates the create/modify/delete lifecycle
- Dates are grouped by **collection**, not list (see `docs/decisions.md` for rationale)
