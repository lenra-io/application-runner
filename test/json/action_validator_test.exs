defmodule ApplicationRunner.ActionValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "action.schema.json" schema
  """

  @relative_path "defs/action.schema.json"

  test "valid action name" do
    assert :ok = ApplicationRunner.UIValidator.validate_for_schema("test", @relative_path, "")

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema("test_hello", @relative_path, "")

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema("TestHello", @relative_path, "")

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema("TEST_HELLO", @relative_path, "")

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema("test42hello", @relative_path, "")

    assert :ok == ApplicationRunner.UIValidator.validate_for_schema("test42", @relative_path, "")
  end

  test "invalid action name" do
    err_pattern = [{"Does not match pattern \"^[a-zA-Z_$][a-zA-Z_$0-9]*$\".", ""}]
    err_integer = [{"Type mismatch. Expected String but got Integer.", ""}]

    assert {:error, err_pattern} ==
             ApplicationRunner.UIValidator.validate_for_schema("", @relative_path, "")

    assert {:error, err_pattern} ==
             ApplicationRunner.UIValidator.validate_for_schema("42", @relative_path, "")

    assert {:error, err_integer} ==
             ApplicationRunner.UIValidator.validate_for_schema(42, @relative_path, "")

    assert {:error, err_pattern} ==
             ApplicationRunner.UIValidator.validate_for_schema("42test", @relative_path, "")

    assert {:error, err_pattern} ==
             ApplicationRunner.UIValidator.validate_for_schema("test space", @relative_path, "")

    assert {:error, err_pattern} ==
             ApplicationRunner.UIValidator.validate_for_schema(
               "test_spécial_char",
               @relative_path,
               ""
             )
  end
end
