require 'restclient'
require 'json'

url = "http://localhost:4567"

## Collection
RestClient.post "#{url}/api/collections", {"name" => "Games"}.to_json

## Lists

# Playthrough Lists
list_ids = []
["Retired", "Completed", "In Progress"].each do |name|
  list_ids << JSON.parse(RestClient.post("#{url}/api/lists", {"name" => name}.to_json).body)['id']
end
# To Play Lists
["Story Focused", "In Between", "Gameplay Focused", "Only Gameplay"].each do |name|
  list_ids << JSON.parse(RestClient.post("#{url}/api/lists", {"name" => name}.to_json).body)['id']
end

## Add list ids to collection
collection = JSON.parse(RestClient.get("#{url}/api/collections").body)[0]
collection['lists'] = list_ids
RestClient.put("#{url}/api/collections/#{collection['id']}", collection.to_json)

## Items

# Retired
lists = JSON.parse(RestClient.get("#{url}/api/lists").body)

retired = []
retired_id = lists.find { |list| list['name'] == "Retired" }['id']
retired.each do |item|
  RestClient.post("#{url}/api/lists/#{retired_id}/items", item.to_json)
end

completed = [
  {'name' => 'Spider-Man: Miles Morales', 'length' => 8, 'platform' => 'ps5', 'finished' => '2022-09-10'},
  {'name' => 'Bugsnax', 'length' => 7, 'platform' => 'ps5', 'finished' => '2022-08-25', 'completionist' => '2022-08-27'},
  {'name' => 'Hades', 'length' => 22, 'platform' => 'ps5', 'finished' => '2022-08-21', 'completionist' => '2022-08-21'},
  {'name' => 'Kingdom Hearts II', 'length' => 32, 'platform' => 'ps4', 'finished' => '2022-01-18', 'completionist' => '2022-01-18', 'replay' => true},
  {'name' => 'Mr. Shifty', 'length' => 4, 'platform' => 'pc', 'finished' => '2022-01-16'},
  {'name' => 'Dicey Dungeons', 'length' => 25, 'platform' => 'switch', 'finished' => '2022-01-15'}
]
completed_id = lists.find { |list| list['name'] == "Completed" }['id']
completed.each do |item|
  RestClient.post("#{url}/api/lists/#{completed_id}/items", item.to_json)
end

in_progress = [
  {'name' => 'Kena: Bridge of Spirits', 'length' => 10, 'platform' => 'ps5', 'started' => true},
  {'name' => 'Final Fantasy VII', 'length' => 48, 'platform' => 'switch', 'started' => true}
]
in_progress_id = lists.find { |list| list['name'] == "In Progress" }['id']
in_progress.each do |item|
  RestClient.post("#{url}/api/lists/#{in_progress_id}/items", item.to_json)
end

story = [
  {'name' => '999: Nine Hours, Nine Persons, Nine Doors', 'length' => 10, 'platform' => 'ps5', 'onHold' => true},
  {'name' => 'Nier Replicant', 'length' => 20, 'platform' => 'ps5', 'onHold' => true},
  {'name' => 'Persona 5 Strikers', 'length' => 38, 'platform' => 'ps5', 'onHold' => true},
  {'name' => 'Tokyo Mirage Sessions', 'length' => 50, 'platform' => 'switch', 'dontOwn' => true}
]
story_id = lists.find { |list| list['name'] == "Story Focused" }['id']
story.each do |item|
  RestClient.post("#{url}/api/lists/#{story_id}/items", item.to_json)
end

between = [
  {'name' => 'Stray', 'length' => 5, 'platform' => 'ps5', 'dontOwn' => true},
  {'name' => 'Sable', 'length' => 7, 'platform' => 'pc', 'dontOwn' => true},
  {'name' => 'Ori and the Will of the Wisps', 'length' => 12, 'platform' => 'switch', 'dontOwn' => true}
]
between_id = lists.find { |list| list['name'] == "In Between" }['id']
between.each do |item|
  RestClient.post("#{url}/api/lists/#{between_id}/items", item.to_json)
end

gameplay = [
  {'name' => 'Thumper', 'length' => 10, 'platform' => 'ps5', 'onHold' => true},
  {'name' => 'Warsaw', 'length' => 7, 'platform' => 'pc'}
]
gameplay_id = lists.find { |list| list['name'] == "Gameplay Focused" }['id']
gameplay.each do |item|
  RestClient.post("#{url}/api/lists/#{gameplay_id}/items", item.to_json)
end

only_gameplay = [
  {'name' => 'Tennis World Tour 2', 'length' => -1, 'platform' => 'ps5', 'onHold' => true},
  {'name' => 'Football Manager 21', 'length' => -1, 'platform' => 'pc'}
]
only_gameplay_id = lists.find { |list| list['name'] == "Only Gameplay" }['id']
only_gameplay.each do |item|
  RestClient.post("#{url}/api/lists/#{only_gameplay_id}/items", item.to_json)
end

