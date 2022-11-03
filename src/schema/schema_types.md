**Single Vars**
---------------
**General Params**
- set_field(type)
  - validation: is type not null/empty, is type correct
- remove_field() _if not a required field, if it's required this isn't generated_

_Special Circumstances_
**Required Field**
No remove field

**Default Value (not implemented yet)**
Remove sets the default value back?


**Boolean** (boolean)
_examples:_
`set_replay(true)`
`remove_replay()`

**Date** (date, date string)
_examples:_
`set_finished(Date.new)`
`set_finished("2016-05-19")`

**String** (string)
_examples:_
`set_name"Something")`
`remove_name()`

**List Vars**
---------------
**General Params**
- set_list(array)
- clear_list()
- add_field(type)
- remove_field(type)

**String** (string)
_examples:_
`set_list(["1", "2", "3"])`
`clear_list()`
`add_field("1")`
`remove_field("1")`

**ObjectId** (responds to :id, string)
_examples:_
`set_list([List.new("id"), List.new("id")])`
`clear_list()`
`add_field(List.new("id"))`
`add_field("id")`
`remove_field(List.new("id"))`
`remove_field("id")`

**User** (user reference)
_examples:_
`set_list([SCOTT, BROOKE])`
`clear_list()`
`add_field(SCOTT)`
`remove_field(SCOTT)`

**Hash Vars**
---------------
**General Params**
- set_hash(hash)
- clear_hash()
- add_field(value)
- update_field(value)
- remove_field(value)

**String** (string)
_examples:_
`set_hash({"1" => "One", "2" => "Two})`
`clear_hash()`
`add_field("1", "One")`
`update_field("1", "Two")`
`remove_field("1")`

for single vars (string, integer, date, boolean, etc)
  - set_field_name
  - remove_field_name

for array var
  - methods that validate before changing anything (example lists)
    - add_list
    - remove_list

for hash var
  - add_field_name(key, value)
  - update_field_name(key, value)
  - remove_field_name(key)

- id
  - UUID

- key, display_name
  - String

- finished, completed
  - Date

- length
  - Integer

- lists
  - Array
    - list
      - UUID

- replay, dont't own
  - Boolean

- templates
  - Hash
    - template
      - Hash

- platforms
  - Array
    - platform
      - Platform (String)

- watched
   - String (Person Enum - Scott, Brooke, Both)
  
- recipe_ingredients
  - Array
    - ingredient
       - String