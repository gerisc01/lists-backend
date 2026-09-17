# lists-backend

The HTTP API behind [games-lists](https://github.com/gerisc01/games-lists): a catalog of things worth
spending time on, and a week planner. Sinatra on Ruby 3.4.2, JSON files for storage.

| Read | For |
|---|---|
| [API.md](API.md) | every endpoint, for a client — refresh with `/api-docs` |
| [SCHEMA.md](SCHEMA.md) | how types, validation, and storage come from the `ruby-schema` gem |
| [PR_GUIDE.md](PR_GUIDE.md) | PR size and template |
| [games-lists NEXT.md](../games-lists/NEXT.md) · [issues](https://github.com/gerisc01/games-lists/issues?q=label%3Abe) | what's next; the backlog is issues labelled `be` |

## Run

```bash
bundle install
ruby api.rb                        # data/, port 9090 (LISTS_BACKEND_PORT to change)
bundle exec ruby e2e_api.rb        # e2e-data/ (wiped on boot), port 9191, no auth
ruby scenarios/start.rb            # scenarios/data/, restored from scenarios/checkpoints/
```

A leftover server keeps its port and serves the **old code**. Check with `lsof -ti :9191`.

| Checkpoint | Sets up |
|---|---|
| `collection-only` | one account, one collection |
| `empty-playthrough-list` | one account, two empty `Games` lists |
| `second-account` | two accounts sharing a collection, no boards |
| `shared-board` | two accounts on one board; `Solo Collection` lists only `123456` |

The client's cache keeps objects a checkpoint lacks, so clear it when switching checkpoints.

`scripts/instance_loop.rb` drives stage → play → finish → replay → backfill against the e2e server in
seconds. `bin/` holds data migrations and `reconcile_loop.sh`; each script's header says how to run
it.

## Test

```bash
bundle exec rake test                                   # always bundle exec — bare rake picks the wrong Sinatra
./test.sh placements_api_test                           # one file
./test.sh placements_api_test test_assign_is_idempotent # one test
```

- Tests subclass `MinitestWrapper`, which sets `TEST_STORAGE` and clears `data-test/` and the day
  cache after each test.
- API tests load `test/test-api.rb`, a trimmed `Api` with **no auth and no CORS**. So
  `current_account_id` is nil there, and membership filtering is off.
- `test/cors_methods_test.rb` fails if a route uses an HTTP verb missing from `allow_methods`.

## How it works

```
request → Api before hook (auth) → route in src/api/*_api.rb → action in src/actions/ → type in src/type/ → data/<type>.json
                                                                                           ↑ errors → src/exceptions_api.rb
```

```
Account
Collection ── lists ── List ── items (ordered ids) ── Item
    │ templates · tags · actions · groups · members        │ status · energy · scheduling.recurrence · owner
CollectionGroup (a board) ── collections · members · one_off_collection
Placement ── item_id · collection_id · date | floating · resolution · staged_week · assignee
Day (date → item ids, the older date model; the planner reads placements)
```

| Piece | How |
|---|---|
| Types | a `Schema` per class; see [SCHEMA.md](SCHEMA.md) |
| CRUD routes | `generate_schema_crud_methods 'items', Item` (`src/api/helpers/list_api_framework.rb`) makes list / get / create / update / delete for tags, templates, itemGroups, lists, actions, items |
| Delta sync | `GET /api/<type>?since=<iso>` → `200 {objects, deleted_ids}`, or `204` if nothing changed. Without `since`, a plain array. `since=now` returns an empty `204` — a starting point |
| Deletes | soft: `deleted: true` stays in the file so sync can report it |
| Auth | `ACCOUNT_ID: <account id>` header on everything except `POST /api/accounts` and OPTIONS. Any real account passes |
| Membership | reads of collections and boards return only records whose `members` include the caller, plus the one-off collection of a board they're on (`members_only`) |
| Placements | one instance of doing an item: on a `date` or `floating` in the staging pile for `staged_week`. `PATCH /api/placements/:pid` sets `resolution` (complete / skip / reopen). The day grid returns resolved placements; the pile doesn't |
| Recurrence | a rule at `item.scheduling.recurrence`: weekly (`floating`, `fixed-day`) or monthly (`date`, `week-of-month`). Untouched occurrences are computed per week (`src/actions/occurrences.rb`), never stored. `POST /api/items/:id/occurrences` turns one into a real placement |
| Reconcile | `POST /api/reconcile` — idempotent sweep of weeks now past: a staged shelf item goes back to its shelf, a one-off lapses, and one-offs whose placements are all resolved are archived. Nothing resolves by time alone. `bin/reconcile_loop.sh` calls it |
| Actions | named multi-step operations (`src/actions/item_actions.rb` registry), run by `POST /api/actions/...`. `reconcile` and `materialize_occurrence` are plain functions, not registry entries |
| Errors | `ListError::BadRequest` / `Validation` → 400, `NotFound` → 404, anything else → 500; body `{error, message}` |

Easy to miss:

- **Storage is fixed at first use.** Changing env vars after boot does nothing.
- **The day cache (PStore) is rebuilt only at boot** (`Day.build_full_day_index`), never during a
  run.
- **Templates validate on save.** Removing a required field from a template breaks every item using
  it on its next `save!`.
- **Boot creates a `todo` template** if it's missing.

### Environments

| Env var | Data directory | Used by |
|---|---|---|
| — | `data/` | `api.rb` |
| `TEST_STORAGE=true` | `data-test/` | tests |
| `LISTS_BACKEND_E2E_TEST=true` | `e2e-data/` | `e2e_api.rb`; also turns auth off |
| `SCENARIO_STORAGE=true` | `scenarios/data/` (or `SCENARIO_DATA_DIR`) | scenario server |

`data/` and `scenarios/data/` are gitignored — copy them before running a migration with `--apply`.

## Where changes go

| Change | Where |
|---|---|
| A field on a type | `src/type/<type>.rb` |
| A new type | `src/type/` (model on `item.rb`), `require_relative` it where it's used, then a `src/api/<type>_api.rb` — `*_api.rb` files load automatically |
| A route | `src/api/<resource>_api.rb` |
| Business logic | `src/actions/`; register it in `item_actions.rb` only if an Action step should call it |
| A template field type | `src/type/template_types/`, required in `src/base_api.rb` |
| Search | `src/query/` — `parser.rb` → `evaluator.rb` → `search.rb` |
| Error → status mapping | `src/exceptions.rb`, `src/exceptions_api.rb` |
| Boot | `BaseApi.start` in `src/base_api.rb` |
| Seed data | `scenarios/checkpoints/`, `api_seeds/` |
