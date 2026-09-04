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
    # Lifecycle status (universal spine). Enforced by the Status validation type.
    {:key => 'status', :required => false, :type => Status, :display_name => 'Status'},
    # Append-only status history; entries shaped/validated by the Transition type.
    {:key => 'transitions', :required => false, :type => Array, :subtype => Transition, :display_name => 'Transitions'},
    # "How much does this demand of me?" (universal spine), enforced by the Energy
    # type. Absent reads as `moderate` — and unlike `status` the default is never
    # stamped on create, so unrated items store nothing. Read via Energy.of_item.
    # Its payoff surface is the planning query; it deliberately does not render on
    # the card (docs/DECISIONS.md).
    {:key => 'energy', :required => false, :type => Energy, :display_name => 'Energy'},
    # Planning kind ({ 'type' => 'event' | 'task' }), enforced by the Scheduling
    # type. Absent reads as `task` (§2.2). Object, not a bare enum, so the optional
    # recurrence rule lives at `scheduling.recurrence` (see recurrence.rb) rather
    # than a second top-level field. First reader is carry-forward (reconcile): tasks
    # carry when their day passes, events resolve.
    {:key => 'scheduling', :required => false, :type => Scheduling, :display_name => 'Scheduling'},
    # WHOSE this usually is — an account id (decision 0083). The durable half of
    # assignment: `placement.assignee` answers who is doing one occurrence, and a
    # placement with no assignee resolves to this. Nothing is copied onto placements,
    # so changing the owner carries every occurrence that was never overridden.
    # Absent means unowned, which is the ordinary state, not an error.
    {:key => 'owner', :required => false, :type => String, :display_name => 'Owner'},
  ]
  apply_schema schema

  # Wrap the schema-generated initializer to apply the birth status default
  # (want-to) on construction, preserving the framework's id generation. New items
  # created via the API are built through `Item.new`, so they get a clean status.
  schema_initialize = instance_method(:initialize)
  define_method(:initialize) do |input = nil|
    schema_initialize.bind(self).call(input)
    self.json['status'] ||= Status::DEFAULT
  end

  # Remove the old validate method and apply the new one that validates the schema and templates
  remove_method :validate if method_defined? :validate
  def validate
    self.class.schema.validate(self)
    # Same rejection update_placement makes for `assignee`, for the same reason: an
    # owner naming no account renders as a blank chip forever with no way to tell it
    # from a display bug. A type_ref would say this declaratively, but it would also
    # make Account a load-order dependency of every item read.
    if !self.owner.nil? && Account.get(self.owner).nil?
      raise ListError::BadRequest, "Unknown owner '#{self.owner}'"
    end
    unless self.templates.nil?
      self.templates.each do |template_id|
        t = Template.get(template_id)
        t.validate_obj(self)
      end
    end
  end

end
