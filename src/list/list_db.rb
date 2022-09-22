class ListDb

  @@file_name = "lists.json"
  @@loaded_objs = nil ## When initialized, is a {}

  def self.cache_loaded?
    return !@@loaded_objs.nil?
  end

  def self.cache_clear
    @@loaded_objs = nil
  end

  def self.file_load
    json = File.exist?(@@file_name) ? JSON.parse(File.read(@@file_name)) : {}
  end

  def self.load
    json = file_load()
    @@loaded_objs = {}
    json.each do |id, json|
      @@loaded_objs[id] = List.from_object(json)
    end
  end

  def self.persist
    persist_objs = {}
    @@loaded_objs.each do |id, list|
      persist_objs[id] = list.to_object
    end
  end

  def self.get(id)
    load unless cache_loaded?()
    return @@loaded_objs[id]
  end

  def self.list
    load unless cache_loaded?()
    @@loaded_objs.values
  end

  def self.save(list)
    load unless cache_loaded?()
    @@loaded_objs[list.id] = list
    persist()
  end

  def self.delete(id)
    load unless cache_loaded?()
    @@loaded_objs.delete(id)
    persist()
  end

end