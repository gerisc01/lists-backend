#!/usr/bin/env ruby
# Migrate a data directory from account-held membership to collection-held membership,
# and from prefs-blob boards to stored collection groups (decisions 0085, 0086, 0087).
#
#   account.collections[]            -> collection.members[]
#   collection.attributes.members    -> collection.members[]     (promoted out of attributes)
#   account.attributes.boards[]      -> collection-group.json
#
# Operates on RAW JSON, not the type layer, on purpose: `account.collections` no longer
# exists in the Account schema, so loading a record through `Account` drops the very field
# this migrates. It also has to run against inert checkpoint folders, which are attached to
# no storage env var at all.
#
# 0087 specifies the union: where `account.collections` and `attributes.members` disagree,
# take BOTH and log it. Under-granting locks someone out of their own data, and there are
# few enough accounts to inspect the disagreements by hand.
#
# Safe by default: DRY RUN (no writes), prints what it would do. Pass --apply to write.
# Idempotent — a migrated directory re-runs as zero changes.
#
#   ruby bin/migrate_membership.rb                                   # dry run, scenarios/data
#   ruby bin/migrate_membership.rb --apply
#   ruby bin/migrate_membership.rb scenarios/checkpoints/second-account --apply --drop-boards
#   ruby bin/migrate_membership.rb data --apply
#
require 'json'
require 'time'

ONE_OFF_TYPE = 'board-one-offs'

apply       = ARGV.include?('--apply')
drop_boards = ARGV.include?('--drop-boards')
prune       = ARGV.include?('--prune-orphan-oneoffs')
dir         = ARGV.reject { |a| a.start_with?('--') }.first || 'scenarios/data'

abort "No such directory: #{dir}" unless Dir.exist?(dir)

# Load a store file into {records, extras}. The gitignored data/ store carries a couple of
# stray top-level scalars alongside the records; they are passed through untouched.
def load_table(dir, name)
  path = File.join(dir, "#{name}.json")
  return [{}, {}, path] unless File.exist?(path)
  raw = JSON.parse(File.read(path))
  records = raw.select { |_, v| v.is_a?(Hash) }
  extras  = raw.reject { |k, _| records.key?(k) }
  [records, extras, path]
end

def write_table(path, records, extras, apply)
  return unless apply
  File.write(path, JSON.generate(records.merge(extras)))
end

accounts,  account_extras,  account_path    = load_table(dir, 'account')
collections, coll_extras,   collection_path = load_table(dir, 'collection')
groups,    group_extras,    group_path      = load_table(dir, 'collection-group')

now = Time.now.utc.iso8601
notes = []
warns = []

# ---------------------------------------------------------------- membership

# Gather every claim on each collection, from all three places it can live.
claimed_by = Hash.new { |h, k| h[k] = [] }   # collection id -> account ids (from account.collections)
accounts.each do |account_id, account|
  (account['collections'] || []).each { |cid| claimed_by[cid] << account_id }
end

membership_changes = 0
collections.each do |cid, collection|
  from_accounts = claimed_by[cid]
  from_attrs    = (collection.dig('attributes', 'members') || [])
  existing      = (collection['members'] || [])

  # 0087's union, in the order that reads best in the file: existing first, then the two
  # legacy sources.
  members = (existing + from_attrs + from_accounts).uniq

  dangling = members.reject { |aid| accounts.key?(aid) }
  unless dangling.empty?
    warns << "collection #{cid} (#{collection['name']}): dropped #{dangling.size} member id(s) with no account: #{dangling.join(', ')}"
    members -= dangling
  end

  if !from_accounts.empty? && !from_attrs.empty? && from_accounts.sort != from_attrs.sort
    notes << "collection #{cid} (#{collection['name']}): sources DISAGREE — " \
             "account.collections says [#{from_accounts.join(', ')}], " \
             "attributes.members says [#{from_attrs.join(', ')}]; took the union"
  end

  had_attr_members = collection['attributes'].is_a?(Hash) && collection['attributes'].key?('members')
  changed = (members.sort != existing.sort) || had_attr_members

  next unless changed
  membership_changes += 1
  puts "#{apply ? 'set' : 'would set'} members on #{cid} (#{collection['name']}) -> [#{members.join(', ')}]"

  collection['members'] = members unless members.empty?
  if had_attr_members
    collection['attributes'].delete('members')
    collection.delete('attributes') if collection['attributes'].empty?
  end
  collection['updated_at'] = now
end

# ---------------------------------------------------------------- boards

# Boards were per-account prefs, so the same board id in two accounts is two PRIVATE
# boards that happen to share a name — not one shared board. Splitting them is the safe
# read; merging would hand each account the other's pile.
board_conversions = 0
unless drop_boards
  accounts.each do |account_id, account|
    boards = account.dig('attributes', 'boards')
    next if boards.nil? || boards.empty?

    boards.each do |board|
      gid = board['id']
      if groups.key?(gid)
        gid = "#{board['id']}-#{account_id}"
        notes << "board '#{board['id']}' exists for another account; account #{account_id} keeps its own as '#{gid}'"
      end
      next if groups.key?(gid)

      group = {
        'id'         => gid,
        'name'       => board['name'],
        'collections' => (board['collections'] || []),
        'members'    => [account_id],
        'updated_at' => now,
      }
      group['one_off_collection'] = board['one_off_collection'] if board['one_off_collection']
      groups[gid] = group
      board_conversions += 1
      puts "#{apply ? 'created' : 'would create'} collection group #{gid} (#{board['name']}) for account #{account_id}"

      # The pad is granted WITH the group (0085), so it needs the holder on it or its
      # owner cannot read back their own one-offs.
      pad = collections[board['one_off_collection']]
      if board['one_off_collection'] && pad.nil?
        warns << "board '#{gid}': one_off_collection #{board['one_off_collection']} does not exist"
      elsif pad && !(pad['members'] || []).include?(account_id)
        pad['members'] = ((pad['members'] || []) + [account_id]).uniq
        pad['updated_at'] = now
        puts "#{apply ? 'granted' : 'would grant'} pad #{board['one_off_collection']} to #{account_id}"
      end

      # active_board follows the id if a collision renamed it. Which board you are LOOKING
      # at stays a personal pref and stays on the account (0085).
      if account.dig('attributes', 'active_board') == board['id'] && gid != board['id']
        account['attributes']['active_board'] = gid
      end
    end
  end
end

# ---------------------------------------------------------------- account cleanup

account_changes = 0
accounts.each do |account_id, account|
  changed = false
  if account.key?('collections')
    account.delete('collections')
    changed = true
  end
  if account['attributes'].is_a?(Hash) && account['attributes'].key?('boards')
    account['attributes'].delete('boards')
    account['attributes'].delete('active_board') if drop_boards
    account.delete('attributes') if account['attributes'].empty?
    changed = true
  end
  next unless changed
  account_changes += 1
  account['updated_at'] = now
  puts "#{apply ? 'cleaned' : 'would clean'} account #{account_id} (#{account['name']})"
end

# ---------------------------------------------------------------- orphan pads

referenced = groups.values.map { |g| g['one_off_collection'] }.compact
orphans = collections.select do |cid, c|
  c.dig('attributes', 'type') == ONE_OFF_TYPE && !referenced.include?(cid)
end

unless orphans.empty?
  if prune
    orphans.each_key do |cid|
      collections.delete(cid)
      puts "#{apply ? 'pruned' : 'would prune'} orphan one-off collection #{cid}"
    end
  else
    orphans.each do |cid, c|
      notes << "orphan one-off collection #{cid} (#{c['name']}) belongs to no board — pass --prune-orphan-oneoffs to remove"
    end
  end
end

# ---------------------------------------------------------------- write + report

write_table(account_path, accounts, account_extras, apply)
write_table(collection_path, collections, coll_extras, apply)
write_table(group_path, groups, group_extras, apply) unless groups.empty? && !File.exist?(group_path)

puts
puts "#{dir}: #{membership_changes} collection(s) given members, " \
     "#{board_conversions} board(s) converted, #{account_changes} account(s) cleaned."
puts "boards dropped (--drop-boards)" if drop_boards
unless notes.empty?
  puts "notes:"
  notes.each { |n| puts "  #{n}" }
end
unless warns.empty?
  puts "WARNINGS:"
  warns.each { |w| puts "  #{w}" }
end
puts '(dry run — pass --apply to write)' unless apply
