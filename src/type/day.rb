require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'

class DailyItem

  schema = Schema.new
  schema.key = "day"
  schema.display_name = "Day"
  schema.fields = [
    {:key => 'id', :required => true, :type => List, :type_ref => true, :display_name => 'List Id'},
    {:key => 'items', :required => false, :type => Array, :subtype => Item, :type_ref => true, :display_name => 'Items'},
  ]
  apply_schema schema

end

class Day

  schema = Schema.new
  schema.key = "day"
  schema.display_name = "Day"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'id', :required => true, :type => String, :display_name => 'Date Id'},
    {:key => 'items', :required => false, :type => Array, :subtype => DailyItem, :display_name => "Today's Items"},
    {:key => 'priorities', :required => false, :type => Array, :subtype => DailyItem, :display_name => "Priority Items"},
  ]
  apply_schema schema

  # Remove the old validate method and apply the new one that validates the schema and templates
  remove_method :validate if method_defined? :validate
  def validate
    self.class.schema.validate(self)
    if !self.items.nil?
      self.items.each do |daily_item|
        daily_item.validate
      end
    end
  end

end
