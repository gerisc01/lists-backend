require_relative './move_item'
require_relative './copy_item'
require_relative './duplicate_item'
require_relative './remove_item'
require_relative './promote_group_item'
require_relative './set_field'
require_relative './add_item_to_field'

def action_methods
  {
    'moveItem' => {
      'method' => :move_item,
      'params' => ['item_id', 'from_list', 'to_list']
    },
    'copyItem' => {
      'method' => :copy_item,
      'params' => ['item_id', 'to_list']
    },
    'duplicateItem' => {
      'method' => :duplicate_item,
      'params' => ['item_id', 'to_list'],
    },
    'removeItem' => {
      'method' => :remove_item,
      'params' => ['item_id', 'from_list', 'item_index']
    },
    'promoteGroupItem' => {
      'method' => :promote_group_item,
      'params' => ['item_id', 'from_list', 'item_index']
    },
    'setField' => {
      'method' => :set_field,
      'params' => ['item_id', 'key', 'value']
    },
    'addItemToField' => {
      'method' => :add_item_to_field,
      'params' => ['item_id', 'key', 'value']
    }
  }
end
