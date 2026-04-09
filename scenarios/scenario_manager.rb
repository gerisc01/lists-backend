# scenarios/scenario_manager.rb

require 'fileutils'

# --- Configuration ---
# __dir__ gives the directory of this file ('scenarios/').
PROJECT_ROOT = File.expand_path('../', __dir__)

# SCENARIOS_BASE_DIR is the directory that will contain all named scenario folders.
SCENARIOS_BASE_DIR = File.join(PROJECT_ROOT, 'scenarios', 'checkpoints')

# CURRENT_SCENARIO_DATA_DIR is the active data directory used by the running server.
CURRENT_SCENARIO_DATA_DIR = File.join(PROJECT_ROOT, 'scenarios', 'data')

PORT = (ENV['LISTS_BACKEND_PORT'] || 9090).to_i

# --- Helper Functions for Scenarios and Checkpoints ---

def clear_directory(path)
  if Dir.exist?(path)
    puts "Clearing directory: #{path}..."
    FileUtils.rm_rf(path)
  end
  FileUtils.mkdir_p(path)
  puts "Directory ensured: #{path}"
end

def copy_directory_contents(source_dir, dest_dir)
  clear_directory(dest_dir)
  if Dir.exist?(source_dir)
    puts "Copying contents from '#{source_dir}' to '#{dest_dir}'..."
    FileUtils.cp_r(File.join(source_dir, '.'), dest_dir)
    puts "Copy complete."
  else
    puts "Warning: Source directory '#{source_dir}' does not exist. Destination '#{dest_dir}' is empty."
  end
end

# Loads data FROM a named scenario folder INTO the CURRENT_SCENARIO_DATA_DIR.
def load_scenario(scenario_name)
  source_path = File.join(SCENARIOS_BASE_DIR, scenario_name)
  unless File.directory?(source_path)
    puts "Error: Scenario '#{scenario_name}' not found at '#{source_path}'."
    return false
  end

  puts "Resetting data to scenario '#{scenario_name}' by loading from '#{source_path}' into '#{CURRENT_SCENARIO_DATA_DIR}'..."
  copy_directory_contents(source_path, CURRENT_SCENARIO_DATA_DIR)
  puts "Scenario '#{scenario_name}' loaded."
  true
end

# Saves data FROM CURRENT_SCENARIO_DATA_DIR TO a named scenario folder.
def create_checkpoint(scenario_name)
  destination_path = File.join(SCENARIOS_BASE_DIR, scenario_name)

  if Dir.exist?(destination_path)
    puts "Error: Checkpoint '#{scenario_name}' already exists. Choose a different name or delete the existing checkpoint first."
    return false
  end

  puts "Creating checkpoint '#{scenario_name}' by saving from '#{CURRENT_SCENARIO_DATA_DIR}' to '#{destination_path}'..."
  copy_directory_contents(CURRENT_SCENARIO_DATA_DIR, destination_path)
  puts "Checkpoint '#{scenario_name}' created at '#{destination_path}'."
  true
end

# Overwrites an existing named scenario folder with current CURRENT_SCENARIO_DATA_DIR.
def update_checkpoint(scenario_name)
  destination_path = File.join(SCENARIOS_BASE_DIR, scenario_name)

  unless Dir.exist?(destination_path)
    puts "Error: Checkpoint '#{scenario_name}' does not exist. Use 'checkpoint' to create a new one."
    return false
  end

  puts "Updating checkpoint '#{scenario_name}' from '#{CURRENT_SCENARIO_DATA_DIR}'..."
  copy_directory_contents(CURRENT_SCENARIO_DATA_DIR, destination_path)
  puts "Checkpoint '#{scenario_name}' updated."
  true
end

# Deletes a named scenario folder after confirmation.
def delete_checkpoint(scenario_name)
  destination_path = File.join(SCENARIOS_BASE_DIR, scenario_name)

  unless Dir.exist?(destination_path)
    puts "Error: Checkpoint '#{scenario_name}' does not exist."
    return false
  end

  print "Are you sure you want to delete checkpoint '#{scenario_name}'? This cannot be undone. (y/n): "
  confirmation = $stdin.gets&.strip&.downcase
  unless confirmation == 'y'
    puts "Delete cancelled."
    return false
  end

  FileUtils.rm_rf(destination_path)
  puts "Checkpoint '#{scenario_name}' deleted."
  true
end

# Lists all named scenario checkpoints in SCENARIOS_BASE_DIR.
def list_scenarios
  entries = Dir.exist?(SCENARIOS_BASE_DIR) ? Dir.entries(SCENARIOS_BASE_DIR)
    .select { |e| File.directory?(File.join(SCENARIOS_BASE_DIR, e)) && !e.start_with?('.') }
    .sort : []

  if entries.empty?
    puts "No saved scenarios found."
  else
    puts "Saved scenarios:"
    entries.each { |e| puts "  #{e}" }
  end
end
