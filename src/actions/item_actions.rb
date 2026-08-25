require_relative './move_item'
require_relative './copy_item'
require_relative './duplicate_item'
require_relative './remove_item'
require_relative './promote_group_item'
require_relative './set_field'
require_relative './add_item_to_field'
require_relative './set_status'
require_relative './assign_to_date'
require_relative './remove_from_date'
require_relative './set_placement_priority'
require_relative './create_floating_placement'
require_relative './bind_placement'
require_relative './update_placement'
require_relative './defer_placement'
require_relative './refloat_placement'
require_relative './delete_placement'
require_relative './auto_archive'
require_relative './create_instance'
require_relative './close_instance'
require_relative './delete_instance'
require_relative './enable_instances'

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
    },
    'setStatus' => {
      'method' => :set_status,
      'params' => ['item_id', 'status']
    },
    'assignToDate' => {
      'method' => :assign_to_date,
      'params' => ['item_id', 'date', 'collection_id']
    },
    'removeFromDate' => {
      'method' => :remove_from_date,
      'params' => ['item_id', 'date', 'collection_id']
    },
    'setPlacementPriority' => {
      'method' => :set_placement_priority,
      'params' => ['item_id', 'date', 'collection_id', 'priority']
    },
    'createFloatingPlacement' => {
      'method' => :create_floating_placement,
      'params' => ['item_id', 'collection_id']
    },
    'bindPlacement' => {
      'method' => :bind_placement,
      'params' => ['placement_id', 'date']
    },
    'updatePlacement' => {
      'method' => :update_placement,
      'params' => ['placement_id', 'fields']
    },
    'deferPlacement' => {
      'method' => :defer_placement,
      'params' => ['placement_id', 'week_start']
    },
    'refloatPlacement' => {
      'method' => :refloat_placement,
      'params' => ['placement_id', 'week_start']
    },
    'deletePlacement' => {
      'method' => :delete_placement,
      'params' => ['placement_id']
    },
    'createInstance' => {
      'method' => :create_instance,
      'params' => ['item_id', 'fields']
    },
    'closeInstance' => {
      'method' => :close_instance,
      'params' => ['instance_id', 'finished_date']
    },
    'deleteInstance' => {
      'method' => :delete_instance,
      'params' => ['instance_id']
    },
    'enableInstances' => {
      'method' => :enable_instances,
      'params' => ['parent_template_id', 'child_template_id']
    }
  }
end
