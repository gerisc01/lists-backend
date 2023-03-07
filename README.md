## Lists
A project used for making a wide range of lists with a standard style and API to be
used across these different types of lists.

## Installation
`bundle install`

## Tests
Run all tests
`rake test`
Run individual tests
`rake test TEST=test/collection/collection_test.rb TESTOPTS="--name=test_collection_add_template -v"`

-----------
## How Schemas Work
-----------
## Fields
Each schema has a list of fields associated with it. Each field will know what fields
are required and what types they are and will handle validation based on that. The fields
are as required:

| field | description |
| ----- | ----------- |
| key          | unique identifying string with no spaces |
| display_name | a display name, no impact other than being available for nicer labeling in potential UIs |
| type         | name of a ruby class, used for validation |
| subtype      | name of a ruby class, used for validation of elements in collections |
| required     | boolean determining if required, if true ValidationError thrown if value not found |
| type_ref     | ??? |
| no_dups      | ??? |

## Type Ref
Type Refs are references to objects that exist without storing the whole object. When retrieving and
when stored in the database, only the id will be saved/returned.

When adding to a type ref feild you can either just send an id or you can send a whole new object and
the type ref backend will handle creating the object for you and then will store the resulting id.

To make this work, type ref heavily relies on the following type fields to process these actions:
- exist?()
- get()
- save()


-------

## Database Generated Methods
-------
## file_based_db_and_cache(database_module, type_class)
Initialized with 2 values:
- Reference to the database module that the methods will be added to
- Reference to the type class that the database stores

`file_based_db_and_cache(Collection::Database, Collection)`

## load()
Loads the items into memory. Items are loaded via the `from_object()` method from json.

`loaded_objs[id] = Collection.from_object(json)`

## persist()
Saves the items into the database. Items are saved via the `to_object()` method as json representations of themselves.

`persist_objs[id] = obj.to_object`

## get(id), list(), save(item), delete(id)
Standard methods to access and modify data. Items are loaded if the cache hasn't been populated yet
and if any changes are made to objects persist is called.

```
# Get a single item based on id
Collection.get("1")
# Get all items
Collection.list()
# Save a type (id is a required field)
Collection.save(collection_instance)
# Delete a type
Collection.delete("1")
```

-------------------------
## Type Generated Methods
-------------------------
## initialize() or initialize(json)
Creates either an empty type or loads a type based on a json object.
- No validation is done on create, validate() needs to be called for that
- If no `id` field is present, one will be generated with a random GUID

```
# Create an empty item
item = Item.new
# Initialized an item from existing data
item = Item.new({'id' => 'key', 'name' => 'A Name'})
```

## validate()
Validates the type using the schema provided to the item.

## from_object(json), to_object(), merge!(json)
- Creates a new object from a json object.
- Returns the json representation of a type.
- Merges json input with the type json. Useful for item updates.

```
# Create an empty item
item = Item.from_object({'id' => 'key', 'name' => 'A Name'})
# To object
item.to_object == {'id' => 'key', 'name' => 'A Name'}
# Merge
item.merge!({'name' => 'A Different Name', 'desc' => 'A Desc'})
item == {'id' => 'key', 'name' => 'A Different Name', 'desc' => 'A Desc'}
```

## get(id), get_by_key(key), exist?(id), list()
- Gets an item by id.
- Gets an item by key. Done by listing items and then filtering on the json value for `'key'`.
- Boolean return if an id exists or not.
- Lists all items for the type.

```
# Get by id
Item.get("1")
# Get by key
Item.get_by_key("a-key")
# Does item exist
Item.get("1") == true
Item.get("2") == false
# List
Item.list()
```

## save!(), delete!()
- Saves an item. Validate will be called before save goes to database.
- Deletes an item. Needs to have an id or the call will fail.

```
# Save an item
item = Item.new({'id' => '1'})
item.save!
# Delete an item
item.delete!
```