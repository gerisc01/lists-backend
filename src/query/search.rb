require_relative '../exceptions'
require_relative '../type/collection'
require_relative '../type/list'
require_relative '../type/item'
require_relative '../type/item_group'
require_relative '../type/tag'
require_relative '../type/status'
require_relative '../type/energy'
require_relative './parser'
require_relative './evaluator'

module Query

  # Built per search by walking collections → lists → items, so an item in no list (a one-off) is
  # never found.
  class CatalogIndex

    Location = Struct.new(:collection_id, :collection_name, :list_id, :list_name)

    attr_reader :items

    def initialize
      @items = {}          # item_id => item json
      @locations = {}      # item_id => [Location]
      @tag_names = {}      # item_id => [tag name]
      @tag_cache = {}      # tag_id => name
    end

    def self.build
      return new.tap(&:load!)
    end

    def load!
      Collection.list({}).each do |collection|
        cj = collection.json
        next if cj['deleted']

        (cj['lists'] || []).each do |list_id|
          list = List.get(list_id)
          next if list.nil? || list.json['deleted']

          location = Location.new(cj['id'], cj['name'], list_id, list.json['name'])
          (list.json['items'] || []).each { |item_id| index_item(item_id, location) }
        end
      end
      return self
    end

    # Always an array, even for single-valued fields.
    def values_for(field, item)
      return case field
      when 'name' then [item['name']].compact
      # Absent means the default, so `energy = moderate` finds unrated items.
      when 'status' then [item['status'] || Status::DEFAULT]
      when 'energy' then [Energy.of(item['energy'])]
      when 'tag' then tag_names_for(item)
      when 'collection' then locations_for(item['id']).map(&:collection_name).uniq
      when 'list' then locations_for(item['id']).map(&:list_name).uniq
      else
        raise ListError::InternalServer, "No resolver for field '#{field}'"
      end
    end

    def locations_for(item_id)
      return @locations[item_id] || []
    end

    private

    def index_item(item_id, location)
      if !@items.key?(item_id)
        item = Item.get(item_id)
        return index_group_members(item_id, location) if item.nil?
        return if item.json['deleted']
        @items[item_id] = item.json
      end

      (@locations[item_id] ||= []) << location
    end

    # A list holds a group's id, not its members'. Members are indexed under the group's location; the
    # group itself isn't, since its status is derived from its members.
    def index_group_members(group_id, location)
      group = ItemGroup.get(group_id)
      return if group.nil? || group.json['deleted']

      (group.group || []).each { |member_id| index_item(member_id, location) }
      return nil
    end

    def tag_names_for(item)
      return @tag_names[item['id']] ||= (item['tags'] || []).map { |tag_id| tag_name(tag_id) }.compact
    end

    # Matched by name: each collection has its own tag record for the same label.
    def tag_name(tag_id)
      return @tag_cache[tag_id] if @tag_cache.key?(tag_id)
      tag = Tag.get(tag_id)
      @tag_cache[tag_id] = tag.nil? ? nil : tag.json['name']
    end

  end

  class Search

    def self.run(query_string, index: nil)
      ast = Parser.parse(query_string)
      index ||= CatalogIndex.build
      evaluator = Evaluator.new(index)
      evaluator.validate!(ast)

      matched = index.items.values.select { |item| evaluator.matches?(ast, item) }
      return group(matched, index)
    end

    # An item in two collections appears under both; within one, once, with every list holding it.
    def self.group(items, index)
      groups = {}

      items.each do |item|
        locations = index.locations_for(item['id'])
        locations.group_by(&:collection_id).each do |collection_id, in_collection|
          group = (groups[collection_id] ||= {
            'collection_id' => collection_id,
            'collection_name' => in_collection.first.collection_name,
            'items' => [],
          })
          group['items'] << item.merge(
            'lists' => in_collection.map { |l| { 'id' => l.list_id, 'name' => l.list_name } },
          )
        end
      end

      sorted = groups.values.sort_by { |g| g['collection_name'].to_s.downcase }
      sorted.each { |g| g['items'].sort_by! { |i| i['name'].to_s.downcase } }

      return {
        'count' => items.length,
        'groups' => sorted,
      }
    end

  end

end
