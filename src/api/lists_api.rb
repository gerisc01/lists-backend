require 'sinatra/base'
require_relative '../type/collection'
require_relative '../type/list'
require_relative '../type/item'

class Api < Sinatra::Base

  # Api Methods
  generate_crud_methods 'collections', Collection
  generate_crud_methods 'lists', List
  generate_crud_methods 'items', Item

end