#!/usr/bin/env ruby
# Backfill first-class Placements from existing Day/DailyItem data (PR 5a, design
# refactor). Each (item, date, collection) assignment in a Day becomes a dated
# Placement (floating:false); each Day.priorities entry sets priority:true on that
# placement. See docs/DECISIONS.md "Placement is a first-class type".
#
# Additive + idempotent: placements SHADOW Day in 5a (nothing user-facing reads
# them yet), and re-running creates nothing new — Placement.find_dated dedupes on
# the (item, date, collection) triple. The per-date priority cap is NOT enforced
# here: the backfill carries existing reality; the cap guards only new writes.
#
# Safe by default: DRY RUN (no writes), prints what it would do. Pass --apply to
# write. Target store follows the usual env vars (default = data/).
#
#   ruby bin/migrate_placements.rb            # dry run against data/
#   ruby bin/migrate_placements.rb --apply    # write to data/
#
require 'json'
# Order matters: Day's DailyItem references Item/Collection at class-load (via
# type_ref), so both must be defined before day.rb is required.
require_relative '../src/type/item'
require_relative '../src/type/collection'
require_relative '../src/type/day'
require_relative '../src/type/placement'
# Load the same type/custom-type environment the app boots, so validating a
# placement (or any referenced item) on save! resolves every referenced constant.
require_relative '../src/type/item_group'
require_relative '../src/type/template_types/dropdown'
require_relative '../src/type/template_types/week_days'
require_relative '../src/type/template_types/integer_patch'
require_relative '../src/type/template_types/recurring_date'

apply = ARGV.include?('--apply')

created = 0
prioritized = 0
skipped_existing = 0
failed = []

# Create the dated placement for (item, date, collection) if absent; set priority
# when asked. Returns a symbol describing what happened (for the counters).
def ensure_placement(item_id, date, collection_id, priority, apply)
  # Referential existence isn't enforced by the Placement schema (ids are plain
  # strings), so guard here — a dangling item id in old Day data shouldn't seed a
  # bad placement.
  return :missing_item unless Item.exist?(item_id)

  existing = Placement.find_dated(item_id, date, collection_id)
  if existing
    if priority && existing.priority != true
      if apply
        existing.priority = true
        existing.validate
        existing.save!
      end
      return :prioritized
    end
    return :exists
  end

  if apply
    placement = Placement.new({
      'item_id' => item_id,
      'collection_id' => collection_id,
      'date' => date,
      'floating' => false,
      'priority' => (priority ? true : false),
    })
    placement.validate
    placement.save!
  end
  priority ? :created_priority : :created
end

# Walk a Day's DailyItem arrays (items and priorities) into placements.
def each_assignment(day)
  { false => day.items, true => day.priorities }.each do |priority, daily_items|
    next if daily_items.nil?
    daily_items.each do |daily_item|
      next if daily_item.items.nil?
      daily_item.items.each { |item_id| yield(item_id, day.id, daily_item.id, priority) }
    end
  end
end

Day.list.each do |day|
  each_assignment(day) do |item_id, date, collection_id, priority|
    begin
      result = ensure_placement(item_id, date, collection_id, priority, apply)
      case result
      when :created, :created_priority
        created += 1
        prioritized += 1 if result == :created_priority
        puts "would create placement #{item_id} @ #{date} (coll #{collection_id})#{priority ? ' [priority]' : ''}" unless apply
      when :prioritized
        prioritized += 1
        puts "would set priority on placement #{item_id} @ #{date}" unless apply
      when :exists
        skipped_existing += 1
      when :missing_item
        failed << "#{item_id} @ #{date}: referenced item no longer exists"
      end
    rescue => e
      failed << "#{item_id} @ #{date}: #{e.message}"
    end
  end
end

verb = apply ? 'created' : 'would create'
puts "#{verb} #{created} placement(s); #{prioritized} priority flag(s); #{skipped_existing} already existed."
unless failed.empty?
  puts "#{failed.size} placement(s) FAILED (left unchanged):"
  failed.each { |f| puts "  #{f}" }
end
puts '(dry run — pass --apply to write)' unless apply
