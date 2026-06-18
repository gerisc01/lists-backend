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
ids.each do |id|
  item = Item.get(id)
  next if item.nil?
  next if Status::TERMINAL.include?(item.json['status']) # already migrated -> idempotent
  next unless item.json['completed'] == true

  migrated += 1
  if apply
    item.json['status'] = 'completed'
    item.save!
  else
    puts "would migrate #{id} (#{item.json['name']}) -> completed"
  end
end

verb = apply ? 'migrated' : 'would migrate'
puts "#{verb} #{migrated} item(s) to 'completed' (of #{ids.size} items)."
puts '(dry run — pass --apply to write)' unless apply
