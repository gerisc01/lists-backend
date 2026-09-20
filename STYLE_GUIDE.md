# Style Guide

How code in this repo is shaped. Where the code disagrees with this guide, the guide wins for new
code.

## File & Folder Organization

```
src/
  api/             # routes, one file per resource — each reopens `class Api < Sinatra::Base`
    helpers/       # route-level helpers: list_api_framework.rb, api_helpers.rb
  actions/         # business logic, one action per file; item_actions.rb is the registry
  type/            # schema classes, one per file
    template_types/  # custom field types, under `class SchemaType`
  query/ filter/   # search
test/              # mirrors src/: test/api, test/actions, test/type
bin/ scripts/      # one-off and repeatable scripts; the header comment is the script's README
```

- An action used by more than one route or action goes in `src/actions/`.
- Every file `require_relative`s what it uses, at the top.

## Naming

| Thing | Convention | Example |
|---|---|---|
| Files, methods, locals | snake_case | `move_item.rb`, `list_id` |
| Classes, modules | PascalCase | `ItemGroup`, `ApiHelpers` |
| Actions | `verb_noun` | `move_item`, `set_status` |
| Registry keys | camelCase | `'moveItem'` |
| Route paths and params | camelCase, and a param names what it identifies | `/api/lists/:listId/items/:itemId` |
| Schema keys | kebab or snake, as stored | `'item-group'`, `'staged_week'` |

Never use a bare `:id` or an abbreviation like `:pid`. Generated CRUD routes derive the param from
the endpoint (`itemGroups` → `:itemGroupId`).

## Routes

Simple CRUD stays inline in the route: get, check, merge, validate, save, respond.

```ruby
put '/api/lists/:listId/items/:itemId' do
  list = List.get(params['listId'])
  raise ListError::NotFound, "List (#{params['listId']}) Not Found" if list.nil?
  item = ItemGeneric.get(params['itemId'])
  raise ListError::NotFound, "Item (#{params['itemId']}) Not Found" if item.nil?
  item.merge!(get_json_payload(request))
  item.validate
  item.save!
  status 200
  body item.to_schema_object.to_json
end
```

- Logic beyond that — several records, rules, anything another route needs — goes in a helper or an
  action, and the route calls it.
- Read the body with `get_json_payload(request)`, not `JSON.parse`.
- Respond with `status` then `body …to_json`, both explicit.
- A route that must come before a generated one (`/api/items/query`) is declared above the
  `generate_schema_crud_methods` call.

## Error Handling

**Whatever the caller talks to directly handles the errors the caller sees.** That layer raises
the specific error; `exceptions_api.rb` maps it to a status.

| Layer | A missing record |
|---|---|
| Route | raises `NotFound` when a lookup returns `nil` |
| Entry-point action — called by a route or an Action step with ids from the request | raises `NotFound` naming the id |
| Lookup or helper — called by other code | `return nil`; the caller decides |

| Problem | Raise | Status |
|---|---|---|
| a record doesn't exist | `ListError::NotFound` | 404 |
| input is missing or wrong | `ListError::BadRequest` | 400 |
| a schema rule fails | `ListError::Validation` (or the gem's `Schema::ValidationError`) | 400 |

- The message names the id or field: `"Item (#{item_id}) Not Found"`.
- **No silent returns.** A helper that can come back empty says so: `return nil if item.nil?`, not
  a bare `return`. An entry point never swallows a problem to return quietly.
- **No blanket rescue.** Don't wrap an action in `rescue Exception` — it catches interrupts and turns
  a 404 into a 400. Rescue a specific error only to translate it.
- `raise`, never `throw`.

## Habits

| Do | Not |
|---|---|
| `return result` on a method's last line — even if no caller uses it yet | an implicit return |
| `if !x.nil?`, `if !list.items.include?(id)` | `unless` |
| `x.to_s.empty?` for "missing or blank" | `x.nil? \|\| x == ''` |
| hash rockets in schema fields: `{:key => 'name', :required => true}` | mixed styles in one list |
| string keys in JSON: `json['id']` | symbol keys |
| 2-space indent | 4 |

**Copied twice → a helper.** A helper removes the duplication and names what the code does.

**Explicit return by default.** Leave it off only when the method has nothing meaningful to return
(it only saves, prints, or loops).

## Actions

```ruby
def move_item(item_id, from_list_id, to_list_id)
  item = ItemGeneric.get(item_id)
  raise ListError::NotFound, "Item (#{item_id}) Not Found" if item.nil?
  ...
  return item
end
```

- A top-level `def`, one per file, named after the file.
- Register it in `item_actions.rb` only if an Action step should call it.

## Testing

```ruby
class MoveItemTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => [@item.id]})
    [@item, @list].each { |obj| obj.save! }
  end

  def test_move_item_to_empty_list
    ...
  end

  def test_move_item_not_found_failure
    assert_raises(ListError::NotFound) { move_item('NOT_FOUND', @list.id, 'b') }
  end

end
```

- Subclass `MinitestWrapper`. It already clears test storage and the day cache after each test.
- `setup` builds only what the tests need, with short literal ids (`'1'`, `'a'`).
- Add `teardown` only for what the wrapper doesn't do — a mocked clock, a toggled env.
- Names are `test_<thing>_<case>`; error cases end in `_failure`.
- API tests include `Rack::Test::Methods` and define `app` as `Api.new` from `test/test-api.rb`.
- A request repeated across tests gets a helper method in the test class.
- Run with `bundle exec`.
