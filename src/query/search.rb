require_relative '../exceptions'
require_relative '../type/collection'
require_relative '../type/list'
require_relative '../type/item'
require_relative '../type/tag'
require_relative '../type/status'
require_relative '../type/energy'
require_relative './parser'
require_relative './evaluator'

module Query

  # Everything a query needs to know about where an item lives, built once per
  # search by walking collections -> lists -> items.
  #
  # The walk is the collection tree rather than `Item.list`, because location is
  # itself queryable (`collection = Recipes`) and is how results are grouped.
  # Consequence worth knowing: an item with no list home — a one-off created
  # directly on the board — is not reachable and will not appear in results.
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
      new.tap(&:load!)
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
      self
    end

    # The resolver contract the Evaluator depends on: field name + item -> values.
    # Always an array; a single-valued field is a one-element one.
    def values_for(field, item)
      case field
      when 'name' then [item['name']].compact
      # Absent status reads as the birth default, and absent energy as moderate —
      # so `energy = moderate` finds everything nobody has rated, which is the
      # whole reason the default is never persisted.
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
      @locations[item_id] || []
    end

    private

    def index_item(item_id, location)
      unless @items.key?(item_id)
        item = Item.get(item_id)
        return if item.nil? || item.json['deleted']
        @items[item_id] = item.json
        # Group children are ordinary items and are just as losable as their
        # parent, so they inherit the parent's location and get indexed too.
        (item.json['children'] || []).each { |child_id| index_item(child_id, location) }
      end

      (@locations[item_id] ||= []) << location
    end

    def tag_names_for(item)
      @tag_names[item['id']] ||= (item['tags'] || []).map { |tag_id| tag_name(tag_id) }.compact
    end

    # Tags are per-collection records, so the same label exists as different ids in
    # different collections. Matching on the *name* is what makes `tag = Me` work
    # as one cross-collection question instead of a per-collection one.
    def tag_name(tag_id)
      return @tag_cache[tag_id] if @tag_cache.key?(tag_id)
      tag = Tag.get(tag_id)
      @tag_cache[tag_id] = tag.nil? ? nil : tag.json['name']
    end

  end

  # Entry point: a query string in, items grouped by collection out.
  class Search

    def self.run(query_string, index: nil)
      ast = Parser.parse(query_string)
      index ||= CatalogIndex.build
      evaluator = Evaluator.new(index)
      evaluator.validate!(ast)

      matched = index.items.values.select { |item| evaluator.matches?(ast, item) }
      group(matched, index)
    end

    # Grouped by collection to match how results are read ("Recipes · Tacos") and
    # because an item's collection is the strongest hint about where you left it.
    # An item in two collections appears under both — that's information, not a
    # duplicate; within a collection it appears once, tagged with the lists that
    # hold it.
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

      {
        'count' => items.length,
        'groups' => sorted,
      }
    end

  end

end
