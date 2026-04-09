# scenarios/start.rb

require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/cors'
require 'fileutils'

require_relative '../src/base_api'
require_relative './scenario_manager'

# --- Main Interaction Loop and Server Management ---

def start_api_server
  pid = fork do
    # --- Logging Setup ---
    log_dir = 'logs'
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
    log_file_path = File.join(log_dir, 'scenario_api.log')

    # Only stdout is redirected — keeps Sinatra's startup noise out of the CLI
    # while letting stderr reach the terminal so real errors surface immediately.
    begin
      $stdout.reopen(log_file_path, 'w')
      $stdout.sync = true

      # SCENARIO_STORAGE tells TypeStorage to use scenarios/data/
      ENV['SCENARIO_STORAGE'] = 'true'

      BaseApi.start(port: PORT)
      Api.run!
    rescue => e
      $stderr.puts "Error during server startup in forked process: #{e.message}"
      $stderr.puts e.backtrace.join("\n")
      exit(1)
    end
  end
  Process.detach(pid)
  puts "Starting API server in background on port #{PORT}..."

  # Brief wait then liveness check — catches silent exits (e.g. exception during cache build)
  # that wouldn't produce stderr output in time to surface on their own.
  sleep 2
  begin
    Process.kill(0, pid)
    puts "API server started with PID: #{pid}"
    puts "Server logs are being written to logs/scenario_api.log"
  rescue Errno::ESRCH
    puts "ERROR: API server failed to start. Last log output:"
    puts "---"
    system("tail -n 20 #{log_file_path}")
    puts "---"
    pid = nil
  end
  pid
end

if __FILE__ == $PROGRAM_NAME
  puts "Welcome to the Scenario Manager API Runner!"
  puts "------------------------------------------"

  api_pid = start_api_server

  puts "Available commands:"
  puts "  reset <scenario_name>      - Loads a saved scenario into the active data directory and restarts the server."
  puts "  checkpoint <scenario_name> - Saves current state as a new scenario (errors if name already exists)."
  puts "  update <scenario_name>     - Overwrites an existing scenario with current state (errors if name not found)."
  puts "  delete <scenario_name>     - Deletes a saved scenario (prompts for confirmation)."
  puts "  list                       - Lists all saved scenarios."
  puts "  status                     - Shows the API server PID."
  puts "  restart                    - Restarts the API server."
  puts "  logs [lines]               - Shows the last [lines] (default 50) of server logs."
  puts "  help                       - Displays this help message."
  puts "  exit                       - Exits the program and stops the API server."
  puts "------------------------------------------"

  loop do
    print "ScenarioManager> "
    command_line = $stdin.gets
    command_line.strip! if command_line

    unless command_line
      puts "\nExiting Scenario Manager due to EOF."
      break
    end

    parts = command_line.split

    case parts[0]
      when "reset"
        if parts.length < 2 || parts[1].empty?
          puts "Usage: reset <scenario_name>"
        else
          scenario_name = parts[1]
          if load_scenario(scenario_name)
            puts "Data reset complete. Restarting API to apply changes..."
            begin
              Process.kill("TERM", api_pid)
              puts "Old API server (PID #{api_pid}) terminated."
            rescue Errno::ESRCH
              puts "API server (PID #{api_pid}) was not running or already terminated."
            rescue => e
              puts "Error terminating API server (PID #{api_pid}): #{e.message}"
            end
            api_pid = start_api_server
            puts "API server restarted."
          end
        end
      when "checkpoint"
        if parts.length < 2 || parts[1].empty?
          puts "Usage: checkpoint <scenario_name>"
        else
          create_checkpoint(parts[1])
        end
      when "update"
        if parts.length < 2 || parts[1].empty?
          puts "Usage: update <scenario_name>"
        else
          update_checkpoint(parts[1])
        end
      when "delete"
        if parts.length < 2 || parts[1].empty?
          puts "Usage: delete <scenario_name>"
        else
          delete_checkpoint(parts[1])
        end
      when "list"
        list_scenarios
      when "status"
        puts api_pid ? "API Server PID: #{api_pid}" : "API server is not running."
      when "restart"
        puts "Restarting API server..."
        begin
          Process.kill("TERM", api_pid)
          puts "Old API server (PID #{api_pid}) terminated."
        rescue Errno::ESRCH
          puts "API server (PID #{api_pid}) was not running or already terminated. Starting a new one."
        rescue => e
          puts "Error terminating API server (PID #{api_pid}): #{e.message}"
        end
        api_pid = start_api_server
        puts "API server restarted."
      when "logs"
        lines_to_show = parts.length > 1 && parts[1].match?(/^\d+$/) ? parts[1].to_i : 50
        log_file_path = 'logs/scenario_api.log'
        if File.exist?(log_file_path)
          puts "--- Last #{lines_to_show} lines of #{log_file_path} ---"
          system("tail -n #{lines_to_show} #{log_file_path}")
          puts "-------------------------------------"
        else
          puts "Log file '#{log_file_path}' not found yet."
        end
      when "help"
        puts "Available commands:"
        puts "  reset <scenario_name>      - Loads data FROM a named scenario folder INTO the current scenario data directory."
        puts "  checkpoint <scenario_name> - Saves current scenario data TO a named scenario folder (errors if name exists)."
        puts "  list                       - Lists all saved scenario checkpoints."
        puts "  status                     - Shows the API server PID."
        puts "  restart                    - Restarts the API server."
        puts "  logs [lines]               - Shows the last [lines] (default 50) of server logs."
        puts "  help                       - Displays this help message."
        puts "  exit                       - Exits the program and stops the API server."
      when "exit"
        puts "Exiting Scenario Manager and stopping API server..."
        begin
          Process.kill("TERM", api_pid)
          puts "API server (PID #{api_pid}) stopped."
        rescue Errno::ESRCH
          puts "API server (PID #{api_pid}) was not running."
        rescue => e
          puts "Error stopping API server (PID #{api_pid}): #{e.message}"
        end
        break
      when ""
        next
      else
        puts "Unknown command: '#{parts[0]}'."
        puts "Type 'help' for a list of available commands."
    end
  end
  exit(0)
end
