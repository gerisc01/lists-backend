require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './tag'
require_relative './template'
require_relative './item_generic'
require_relative './status'
require_relative './energy'
require_relative './scheduling'
require_relative './account'

class Item

  schema = Schema.new
  schema.key = "item"
  schema.display_name = "Item"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    {:key => 'templates', :required => false, :type => Array, :subtype => Template, :type_ref => true, :set => true, :display_name => 'Template'},
    {:key => 'tags', :required => false, :type => Array, :subtype => Tag, :type_ref => true, :display_name => 'Tags'},
    {:key => 'parent', :required => false, :type => ItemGeneric, :type_ref => true, :display_name => 'Parent'},
    {:key => 'children', :required => false, :type => Array, :subtype => ItemGeneric, :type_ref => true, :display_name => 'Children'},
    {:key => 'status', :required => false, :type => Status, :display_name => 'Status'},
    # Append-only; set_status writes it.
    {:key => 'transitions', :required => false, :type => Array, :subtype => Transition, :display_name => 'Transitions'},
    # Absent means `moderate`; read it with Energy.of_item.
    {:key => 'energy', :required => false, :type => Energy, :display_name => 'Energy'},
    # Holds `recurrence` (recurrence.rb).
    {:key => 'scheduling', :required => false, :type => Scheduling, :display_name => 'Scheduling'},
    # An account id. A placement with no assignee falls back to this; absent means unowned.
    {:key => 'owner', :required => false, :type => String, :display_name => 'Owner'},
  ]
  apply_schema schema

  # Wraps the gem's initializer to default `status` to want-to.
  schema_initialize = instance_method(:initialize)
  define_method(:initialize) do |input = nil|
    schema_initialize.bind(self).call(input)
    self.json['status'] ||= Status::DEFAULT
  end

  # Replaces the gem's validate to also check the owner and the item's templates.
  remove_method :validate if method_defined? :validate
  def validate
    self.class.schema.validate(self)
    # Not a type_ref, which would make every item read load Account.
    if !self.owner.nil? && Account.get(self.owner).nil?
      raise ListError::BadRequest, "Unknown owner '#{self.owner}'"
    end
    if !self.templates.nil?
      self.templates.each do |template_id|
        t = Template.get(template_id)
        t.validate_obj(self)
      end
    end
  end

end
