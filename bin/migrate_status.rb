#!/usr/bin/env ruby
# Backfill lifecycle `status` onto existing items (PR 1, design refactor).
#
# Minimal + idempotent: the only state worth migrating is the legacy `completed`
# boolean, so items with `completed: true` get `status: 'completed'`. Everything
# else is left alone — Item#initialize defaults absent status to `want-to` on read,
# so there's no need to rewrite untouched records.
#
# Safe by default: runs as a DRY RUN (no writes) and prints what it *would* change.
# Pass --apply to actually write. Target store follows the usual env vars
# (default = data/; SCENARIO_STORAGE / LISTS_BACKEND_E2E_TEST select the others).
#
#   ruby bin/migrate_status.rb            # dry run against data/
#   ruby bin/migrate_status.rb --apply    # write to data/
#
require 'json'
require_relative '../src/type/item'
# Load the same type/custom-type environment the app boots (base_api.rb), so
# validating any item on save! resolves every referenced constant:
#   - ItemGroup, referenced by item_generic for parent/children fields
#   - the template custom types (RecurringDate, Dropdown, WeekDays, IntegerPatch)
require_relative '../src/type/item_group'
require_relative '../src/type/template_types/dropdown'
require_relative '../src/type/template_types/week_days'
require_relative '../src/type/template_types/integer_patch'
require_relative '../src/type/template_types/recurring_date'

apply = ARGV.include?('--apply')

# Resolve the active store directory the same way src/storage.rb does.
store_dir =
  if TypeStorage.is_e2e_test                then 'e2e-data'
  elsif TypeStorage.scenario_var_set        then (ENV['SCENARIO_DATA_DIR'] || 'scenarios/data')
  elsif TypeStorage.test_var_set            then 'data-test'
  else                                           'data'
  end

# Read ids straight from the store file's keys, filtering out any stray non-item
# entries (the gitignored data/ store has a couple of top-level scalar keys).
raw = JSON.parse(File.read(File.join(store_dir, 'item.json')))
ids = raw.select { |_, v| v.is_a?(Hash) && v['id'] }.keys

migrated = 0
failed = []
ids.each do |id|
  item = Item.get(id)
  next if item.nil?
  next if Status::TERMINAL.include?(item.json['status']) # already migrated -> idempotent
  next unless item.json['completed'] == true

  if apply
    begin
      item.json['status'] = 'completed'
      item.save!
      migrated += 1
    rescue => e
      failed << "#{id} (#{item.json['name']}): #{e.message}"
    end
  else
    migrated += 1
    puts "would migrate #{id} (#{item.json['name']}) -> completed"
  end
end

verb = apply ? 'migrated' : 'would migrate'
puts "#{verb} #{migrated} item(s) to 'completed' (of #{ids.size} items)."
unless failed.empty?
  puts "#{failed.size} item(s) FAILED to save (left unchanged):"
  failed.each { |f| puts "  #{f}" }
end
puts '(dry run — pass --apply to write)' unless apply
