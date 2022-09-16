require_relative './base_service'

class List < BaseService

  @file_name = "lists.json"
  @loaded_objs = nil

  ## Model
  attr_accessor :name

  def initialize(name)
    super()
    raise "Name must be non-nil" if name.nil?
    @name = name
  end

  def validate
    raise "Invalid List: id cannot be null" if @id == nil
    raise "Invalid List (#{@id}): name cannot be null" if @name == nil
  end

end