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

The scenario manager (`scenarios/scenario_manager.rb`) loads checkpoint data from `scenarios/checkpoints/`. Available checkpoints are in that directory.

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
