# Development Guide

## Setup

```bash
bundle install
```

Ruby version is pinned in `.ruby-version` (3.4.2). Use rbenv or rvm to match it.

## Running the Server

```bash
ruby api.rb                           # production data (data/)
LISTS_BACKEND_PORT=9091 ruby api.rb   # custom port (default 9090)
```

On startup the server:
1. Creates the `todo` template if it doesn't exist
2. Mirrors the storage environment in the Day cache
3. Rebuilds the full day index in PStore

## Running the Scenario Server

Scenarios are interactive checkpoints for development and demo. They run against `scenarios/data/` and restore from named checkpoints.

```bash
ruby scenarios/start.rb
```

The scenario manager (`scenarios/scenario_manager.rb`) loads checkpoint data from `scenarios/checkpoints/`.

| Checkpoint | Sets up |
|---|---|
| `collection-only` | one account, one collection, no lists |
| `empty-playthrough-list` | one account, two `Games` lists, no items |
| `second-account` | two accounts, one shared collection, **no boards** |
| `shared-board` | two accounts on **one shared board**, no items |

All four carry membership as `collection.members`; none carries `account.collections`.

`second-account` has no boards on purpose — creating one is how you exercise `BoardAdd`, the whole
new write path (pad + group + `active_board`).

`shared-board` is the lens case from decision 0085 (`games-lists/docs/decisions/`): the board
`Shared Planning` names two collections and both accounts hold the board, but `Solo Collection`
lists only `123456`. Account `654321` should get the *no access* row for it rather than a board
that silently omits it. `Shared Planning one-offs` is the shared pad, granted with the board.

The client's cache outlives a reset for objects a checkpoint LACKS (`restamp_updated_at` never
marks absences deleted), so clear it when switching between checkpoints with different items.

## Migrating a store to collection-held membership

`bin/migrate_membership.rb` moves a data directory onto the model in decisions 0085–0087:
`account.collections[]` and `collection.attributes.members` become `collection.members[]`, and
`account.attributes.boards[]` become records in `collection-group.json`. Dry run by default.

```bash
ruby bin/migrate_membership.rb                                                    # dry run, scenarios/data
ruby bin/migrate_membership.rb data --apply                                       # the real store
ruby bin/migrate_membership.rb scenarios/checkpoints/<name> --apply --drop-boards # a checkpoint
```

It reads raw JSON rather than the type layer on purpose — `Account` no longer declares
`collections`, so loading a record through it drops the field being migrated — and it runs against
inert checkpoint folders, which no storage env var points at.

| Flag | Effect |
|---|---|
| `--apply` | write; without it, prints what it would do |
| `--drop-boards` | discard boards instead of converting them — for checkpoints you want to restore board-less, so that creating one exercises the real write path |
| `--prune-orphan-oneoffs` | delete `board-one-offs` collections no board points at |

Where `account.collections` and `attributes.members` disagree it takes the **union** and logs the
pair, per 0087: under-granting locks someone out of their own data. The same board id under two
accounts is two *private* boards, so the second is renamed `<id>-<account_id>` and that account's
`active_board` follows it. Re-running is a no-op.

**`data/` and `scenarios/data/` are gitignored — copy them before `--apply`.**

## Driving the instance loop

`scripts/instance_loop.rb` runs the whole repeat-engagement arc — stage a game, play a session,
come back the following week, finish it, replay it two years later, backfill 2016 — against the
disposable e2e backend. Every date and `staged_week` is a parameter, so a multi-week story takes
about two seconds and no waiting.

```bash
bundle exec ruby e2e_api.rb       # terminal 1
ruby scripts/instance_loop.rb     # terminal 2 — rerunnable, wipes first
```

Unit tests cover the rules in isolation; this covers the **serialized shape a client receives**.
`catalog_item_id` and `one_off` are derived at the API boundary, and getting them wrong is what
buries a playthrough in the One-offs pile instead of its own collection.

## Driving the API end-to-end by hand

`bundle exec ruby e2e_api.rb` serves the real API on **port 9191**, clearing `e2e-data/` on boot and
skipping auth on the items/placements/reconcile routes. It's the cheapest way to exercise a whole
flow without the frontend:

```bash
POST   /api/collections
POST   /api/items
POST   /api/items/:id/placements   {collection}
GET    /api/placements/floating?collections=
POST   /api/reconcile
DELETE /api/items/:id
```

> **Check for a stale process first: `lsof -ti :9191`.** A long-running backend left over from an
> earlier session keeps the port, your new process loses it to `EADDRINUSE`, and curl then hits the
> **old code** — which looks exactly like your change not working. Kill it before starting.

## Running Tests

```bash
bundle exec rake test                                       # all tests
bundle exec rake test TEST=test/api/collections_test.rb    # one file
bundle exec rake test TEST=test/api/collections_test.rb TESTOPTS="--name=test_add_template -v"
```

Or use the convenience script:
```bash
./test.sh collections_test test_add_template
```

### Test Infrastructure

- `MinitestWrapper` (test/minitest_wrapper.rb) — base class for all tests; calls `TypeStorage.clear_test_storage` and `Day.clear_cache` after each test
- Tests use `TEST_STORAGE=true` automatically; test data goes to `data-test/`
- Tests that exercise date queries must call `Day.toggle_cache_source(:test)` in setup and `Day.build_full_day_index` after loading fixtures

## Adding a New Domain Type

1. Create `src/type/my_type.rb` — follow the pattern in `src/type/item.rb`:
   - Build a `Schema`, set `key`, `storage`, `accessors`, `fields`
   - Call `apply_schema schema`
   - Override `validate` only if you need custom validation beyond schema rules
2. `require_relative` it in `src/base_api.rb` (or it won't load)
3. Create `src/api/my_type_api.rb`:
   ```ruby
   class MyTypeApi < Sinatra::Base
     register Sinatra::ListApiFramework
     generate_schema_crud_methods 'my-types', MyType
   end
   ```
   Custom routes go in the same class below the `generate_schema_crud_methods` call.
4. No further registration needed — `base_api.rb` auto-requires all `*_api.rb` files via glob.
5. Add tests in `test/type/my_type_test.rb` and `test/api/my_type_api_test.rb`.

## Adding a Custom Template Field Type

1. Create `src/type/template_types/my_type.rb` — implement `validate(value)` (raise `ListError::Validation` on failure)
2. `require_relative` it in `src/base_api.rb` alongside the other template types
3. Register the type string → class mapping (see how `Dropdown` or `WeekDays` is registered)

## Adding a Custom Action

1. Create `src/actions/my_action.rb` with a method that takes `(item, params)`
2. Register it in `src/actions/item_actions.rb` in the actions registry hash
3. It can then be referenced by name in Action schema objects

## Debugging Tips

**Storage not persisting between calls**: Check which environment is active. `TypeStorage.global_storage` is a singleton — once set it won't change. Check env vars (`LISTS_BACKEND_E2E_TEST`, `SCENARIO_STORAGE`, `TEST_STORAGE`).

**Date queries returning wrong results**: The day cache may be stale. Restart the server to rebuild. In tests, call `Day.build_full_day_index` explicitly.

**Validation errors on items that weren't changed**: A template applied to the item has been modified — its fields now fail validation on the existing item data.

**Type ref field not updating**: Confirm you're sending an object with an `id` field or a plain ID string. Sending an object without `id` will auto-create a new record every time.
