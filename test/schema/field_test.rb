require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../helpers'
require_relative '../../src/schema/schema'
require_relative '../../src/schema/custom_types'
# require_relative '../../src/type/template'

class FieldTest < Minitest::Test

  def setup
  end

  def teardown
  end

  ########## Required ##########

  def test_field_required
    field = Field.from_obj("field", {:required => true})
    # nil fails
    assert_raises do
      field.validate(nil)
    end
    # empty fails
    assert_raises do
      field.validate("")
    end
    # present success
    field.validate("value")
  end

  def test_field_not_required
    field = Field.from_obj("field", {:required => false})
    # nil success
    field.validate(nil)
    # empty success
    field.validate("")
    # present success
    field.validate("value")
  end

  ########## Type ##########

  def test_field_type
    field = Field.from_obj("field", {:type => String})
    # nil success
    field.validate(nil)
    # present success
    field.validate("value")
    # wrong type fail
    assert_raises do
      field.validate(2)
    end
  end

  def test_field_type_array_no_subtype
    field = Field.from_obj("field", {:type => Array})
    # empty success
    field.validate([])
    # mixed values success
    field.validate([1, true, "something"])
  end

  def test_field_type_custom_type
    field = Field.from_obj("field", {:type => SchemaType::Boolean})
    # nil success
    field.validate(nil)
    # present success case #1
    field.validate(true)
    # present success case #2
    field.validate(false)
    # wrong type fail
    assert_raises do
      field.validate(1)
    end
  end

  ########## Subtype Array ##########

  def test_field_subtype_array
    field = Field.from_obj("field", {:type => Array, :subtype => String})
    # empty success
    field.validate([])
    # string values success
    field.validate(["a", "quick", "fox"])
    # mixed values fail
    assert_raises do
      field.validate([1, true, "something"])
    end
  end

  def test_field_subtype_array_custom_type
    field = Field.from_obj("field", {:type => Array, :subtype => SchemaType::Boolean})
    # empty success
    field.validate([])
    # custom type values success
    field.validate([true, false])
    # mixed values fail
    assert_raises do
      field.validate([true, "something"])
    end
  end

  ########## Subtype Hash ##########

  def test_field_subtype_hash
    field = Field.from_obj("field", {:type => Hash, :subtype => String})
    # empty success
    field.validate({})
    # string values success
    field.validate({"a" => "1", "quick" => "14"})
    # mixed values fail
    assert_raises do
      field.validate({"a" => 2, "quick" => 15})
    end
  end

  def test_field_subtype_hash_custom_type
    field = Field.from_obj("field", {:type => Hash, :subtype => SchemaType::Boolean})
    # custom type values success
    field.validate({"a" => true, "quick" => false})
    # mixed values fail
    assert_raises do
      field.validate({"a" => true, "quick" => "false"})
    end
  end

  ########## TypeRef ##########

  def test_field_typeref
    field = Field.from_obj("field", {:type => TypeRefClass, :type_ref => true})
    typeref = TypeRefClass.new("1")
    # type instance success
    field.validate(typeref)
    # matching id (1) success
    field.validate("1")
    # other type fail
    assert_raises do
      field.validate(1)
    end
    # non-matching id fail
    assert_raises do
      field.validate("2")
    end
  end

  def test_field_array_typeref_pass
    field = Field.from_obj("field", {:type => Array, :subtype => TypeRefClass, :type_ref => true})
    typeref = TypeRefClass.new("1")
    # type instance fail
    assert_raises do
      field.validate(typeref)
    end
    # subtype instance success
    field.validate([typeref])
    # matching id (1) success
    field.validate(["1"])
    # other type fail
    assert_raises do
      field.validate([1])
    end
    # non-matching id fail
    assert_raises do
      field.validate(["2"])
    end
  end

  def test_field_hash_typeref_pass
    field = Field.from_obj("field", {:type => Hash, :subtype => TypeRefClass, :type_ref => true})
    typeref = TypeRefClass.new("1")
    # type instance fail
    assert_raises do
      field.validate(typeref)
    end
    # subtype instance success
    field.validate({"a" => typeref})
    # matching id (1) success
    field.validate({"a" => "1"})
    # other type fail
    assert_raises do
      field.validate({"a" => 1})
    end
    # non-matching id fail
    assert_raises do
      field.validate({"a" => "2"})
    end
  end

end