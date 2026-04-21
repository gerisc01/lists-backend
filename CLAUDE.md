# lists-backend

A schema-driven RESTful API (Sinatra/Ruby) for managing hierarchical lists, collections, items, templates, and recurring date events. Multi-tenant via account-scoped auth. File-based JSON storage with a PStore day-cache layer.

See `docs/decisions.md` for current in-progress work and recent design decisions.

---

## Pattern Vocabulary

Understanding these four patterns lets you read any file in the codebase without surprises.

**1. Schema-driven types (`ruby-schema`)**
Every domain type is defined by building a `Schema` object, setting its fields, and calling `apply_schema schema` at the bottom of the class file. This macro-generates `initialize`, `validate`, `from_object`, `to_object`, `merge!`, `get`, `list`, `exist?`, `save!`, and `delete!`. You will *not* find these methods implemented explicitly in type files — they come from the gem.

**2. ListApiFramework**
`generate_schema_crud_methods(endpoint, clazz)` in `src/api/helpers/list_api_framework.rb` registers the five standard REST endpoints (LIST, GET, CREATE, UPDATE, DELETE) for any type. Most `*_api.rb` files are thin: one `generate_schema_crud_methods` call plus any custom routes.

**3. Type refs (`type_ref: true`)**
Schema fields marked `type_ref: true` store only IDs in JSON but can *accept* full objects on write — the framework auto-creates the object and stores the resulting ID. This is invisible in the type definition; watch for it when debugging unexpected object creation on PUT.

**4. Soft deletes**
`delete!` sets `deleted: true` on the record; it does not remove the file. `list()` without options excludes deleted records. `list({include_deleted: true})` returns all. Sync responses (`?since=`) separate `deleted_ids` from live `objects`.

---

## File Map

| Goal | File(s) |
|---|---|
| Add or change a CRUD endpoint | `src/api/helpers/list_api_framework.rb`, then the relevant `src/api/*_api.rb` |
| Add a new domain type | `src/type/` — model after `item.rb`; register storage in `src/storage.rb` only if the type needs a different storage instance |
| Debug authentication | `src/base_api.rb` — `protected!` helper, `before` hook |
| Debug date or recurring-event logic | `src/api/dates_api.rb`, `src/api/helpers/date_helpers.rb` |
| Debug field validation | `src/type/*.rb` schema definition, then the `ruby-schema` gem |
| Debug storage environment routing | `src/storage.rb` — `TypeStorage.global_storage` |
| Debug day index / date queries | `src/type/day.rb` |
| Add a custom template field type | `src/type/template_types/` |
| Understand action execution | `src/actions/item_actions.rb` (registry), `src/actions/*.rb` (implementations) |
| Change error behavior | `src/exceptions.rb` (classes), `src/exceptions_api.rb` (HTTP mappings) |
| Understand startup sequence | `src/base_api.rb` — `BaseApi.start` |
| Change scenario/test data setup | `scenarios/start.rb`, `scenarios/scenario_manager.rb` |

---

## Non-Obvious Constraints

- **Only unauthenticated endpoint**: `POST /api/accounts`. Auth is also skipped globally when `LISTS_BACKEND_E2E_TEST=true` (the `Api` class `before` hook, not `BaseApi`).
- **Storage singleton**: `TypeStorage.global_storage` is set once per process on first call. Changing env vars after startup has no effect. Storage environment is determined at boot.
- **Cache must mirror storage**: The Day PStore cache has its own environment flag, toggled separately via `Day.toggle_cache_source(env)`. `BaseApi.start` syncs them; if you set up a test environment manually, you must also toggle the cache.
- **Day cache is not auto-maintained**: It's rebuilt at startup (`Day.build_full_day_index`) and never updated incrementally during a run. Tests that exercise date queries must call `Day.build_full_day_index` explicitly after loading fixtures.
- **Test teardown requires two clears**: `TypeStorage.clear_test_storage` (JSON files) AND `Day.clear_cache` (PStore). Missing the cache step causes cross-test pollution in date-related tests.
- **Template validation runs at save time**: `Item#validate` calls `template.validate_obj(self)` for each applied template. Removing a required field from a template invalidates all items that use it on their next `save!`.
- **`todo` template is auto-created**: `BaseApi.start` creates the `todo` template if it doesn't exist. Do not assume it's absent in a fresh data directory.
- **`merge!` on type-ref arrays replaces by ID**: Sending a full object in a type-ref field auto-creates it. Sending an ID string uses the existing record. Order matters for array fields with `set: true`.

---

## Storage Environments

| Env var | Directory | Used by |
|---|---|---|
| *(none)* | `data/` | Production |
| `TEST_STORAGE=true` | `data-test/` | Unit & integration tests |
| `LISTS_BACKEND_E2E_TEST=true` | `e2e-data/` | E2E test suite |
| `SCENARIO_STORAGE=true` | `scenarios/data/` (or `SCENARIO_DATA_DIR`) | Scenario runner |

---

## Entity Hierarchy

```
Account
└── Collections
    ├── Lists
    │   └── Items  (can have templates, tags, parent/children)
    ├── ItemGroups (bundle of Items; propagates template changes to members)
    ├── ListGroups
    ├── Templates  (define required/optional fields; applied to lists or items)
    ├── Actions    (chainable multi-step operations on items)
    └── Tags
Days  (cross-cutting; a date → [item_ids] index, cached in PStore)
```

---

## Test Commands

```bash
bundle exec rake test                                    # all tests
bundle exec rake test TEST=test/api/dates_test.rb        # one file
bundle exec rake test TEST=test/api/dates_test.rb TESTOPTS="--name=test_name -v"
```

Deeper reference: `docs/development.md`
