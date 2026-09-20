# Schema

Every stored type is a plain Ruby class that hands a `Schema` to the `ruby-schema` gem
([source](https://github.com/gerisc01/ruby-schema), 0.6.2), which generates its methods and storage.

```ruby
class Item
  schema = Schema.new
  schema.key = "item"                          # table name → data/item.json
  schema.display_name = "Item"                 # used in validation messages
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => true, :type => String},
    {:key => 'tags', :type => Array, :subtype => Tag, :type_ref => true},
    {:key => 'status', :type => Status},       # a custom type, see below
  ]
  apply_schema schema
end
```

A record is a hash in `instance.json`. Nothing is copied into instance variables, so a field the
schema doesn't declare still round-trips.

## Fields

| Option | Effect |
|---|---|
| `key` | JSON key and accessor name |
| `required` | `validate` raises if nil or empty |
| `type` / `subtype` | class the value (or each element) must be; `subtype` applies to `Array` and `Hash` |
| `type_ref` | stores only the id — see below |
| `display_name` | label only |
| anything else | kept in `field.extra_attrs`, which the gem ignores. `Dropdown` reads `static_options` / `list_options` from it; `set: true` on `Item.templates` enforces nothing |

## What `apply_schema` generates

| Generated | Behavior |
|---|---|
| `new(json = nil)` | wraps the hash; assigns a UUID `id` if missing; **no validation** |
| `<field>` / `<field>=` | getter converts nested schema objects; setter validates the value, then stores it |
| `add_<field>` / `remove_<field>` | for `Array` fields (the key minus a trailing `s`) |
| `upsert_<field>` / `remove_<field>` | for `Hash` fields |
| `validate` | checks every field; raises `Schema::ValidationError` |
| `merge!(json)` | shallow `Hash#merge` — a nested object is replaced, not merged |
| `to_schema_object` / `from_schema_object` | the JSON hash out / a new instance in |
| `==` | same class and equal JSON |

With `storage` and `accessors` set:

| Accessor | Behavior |
|---|---|
| `Type.get(id, since:)` | `nil` if missing, soft-deleted, or older than `since` |
| `Type.exist?(id)` | `get(id) != nil` — a soft-deleted record doesn't exist |
| `Type.list(since:, include_deleted:)` | excludes soft-deleted unless `include_deleted: true`; `since` keeps records with `updated_at` after it |
| `instance.save!` | runs `validate`, stamps `updated_at`, writes |
| `instance.delete!` | sets `deleted: true`, stamps `updated_at`, writes. Nothing is removed |

## Type refs

A `type_ref` field stores ids. On write it accepts an id (which must exist) or an instance (saved
first if its id doesn't exist yet). So a `PUT` carrying a full object in a type-ref field creates that
object.

## Custom types

A class used as `type` can define any of these, and the gem calls them:

| Hook | Called by |
|---|---|
| `self.type_match?(value)` | type checks — lets a `Hash` or `String` count as this type |
| `self.field_value_validation(field, value)` | `validate`, after the type check |
| `self.field_def_validation(field)` | schema load, to reject a bad field definition |

`Status`, `Energy`, `Scheduling`, `Recurrence`, `Resolution`, `SharingScope`, `ItemGeneric` and the
template field types in `src/type/template_types/` work this way.

## Storage

`SchemaTypeStorage` keeps one JSON file per table (`<dir>/<key>.json`, `{id => record}`) and an
in-memory copy loaded on first access. Every `save!` or `delete!` rewrites that table's whole file
under a per-table mutex. The directory is fixed per process — see `README.md` § Environments.
