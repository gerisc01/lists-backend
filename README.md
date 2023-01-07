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


## How Schemas Work
# Field
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