require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../helpers'
require_relative '../../src/schema/schema'
require_relative '../../src/schema/custom_types'
# require_relative '../../src/type/template'

class CustomTypesTest < Minitest::Test

  def setup
  end

  def teardown
  end

  def test_field_boolean
    field = Field.from_obj("field", {:type => SchemaType::Boolean})
    # true success
    field.validate(true)
    # false success
    field.validate(false)
    # true string fail
    assert_raises do
      field.validate("true")
    end
  end

  def test_field_date
    field = Field.from_obj("field", {:type => SchemaType::Date})
    # date object success
    field.validate(Date.new)
    # date string success
    field.validate("2022-12-31")
    # invalid date string fail
    assert_raises do
      field.validate("2022-12-50")
    end
  end

end