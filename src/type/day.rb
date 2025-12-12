require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'
require 'pstore'

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

  def self.build_full_day_index
    Dir.mkdir('cache') unless Dir.exist?('cache')
    item_to_days = PStore.new('cache/item_to_days.pstore')
    item_to_days.transaction do
      days = self.list
      days.each do |day|
        date = day.id
        day.items.each do |daily_items|
          daily_items.items.each do |item_id|
            item_to_days[item_id] = [] unless item_to_days.key?(item_id)
            item_to_days[item_id] << date
          end
        end
      end
    end
  end

  def self.get_days_for_item(item_id)
    item_to_days = PStore.new('cache/item_to_days.pstore')
    days = []
    item_to_days.transaction(true) do
      if item_to_days.key?(item_id)
        days = item_to_days[item_id]
      end
    end
    return days
  end

  def self.add_day_for_item(item_id, date)
    item_to_days = PStore.new('cache/item_to_days.pstore')
    item_to_days.transaction do
      item_to_days[item_id] = [] unless item_to_days.key?(item_id)
      item_to_days[item_id] << date unless item_to_days[item_id].include?(date)
    end
  end

  def self.remove_day_for_item(item_id, date)
    item_to_days = PStore.new('cache/item_to_days.pstore')
    item_to_days.transaction do
      if item_to_days.key?(item_id)
        item_to_days[item_id].delete(date)
        if item_to_days[item_id].empty?
          item_to_days.delete(item_id)
        end
      end
    end
  end

  def self.clear_day_index
    if File.exist?('cache/item_to_days.pstore')
      File.delete('cache/item_to_days.pstore')
    end
  end
end
