defmodule ApplicationRunner.TextfieldValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "textfield.schema.json" schema
  """

  @relative_path "components/textfield.schema.json"

  test "valide textfield" do
    json = %{
      "type" => "textfield",
      "value" => "",
      "onChange" => %{
        "action" => "anyaction",
        "props" => %{
          "number" => 10,
          "value" => "value"
        }
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valide textfield with no listener" do
    json = %{
      "type" => "textfield",
      "value" => "test"
    }

    assert {:ok, json} ==
      ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalide type textfield" do
    json = %{
      "type" => "textfields",
      "value" => "test"
    }

    assert {:error, [{"textfields is invalid. Should have been textfield", "/type"}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalid textfield with no value" do
    json = %{
      "type" => "textfield"
    }

    assert {:error, [{"Required property value was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalid textfield with invalid action and props in listener" do
    json = %{
      "type" => "textfield",
      "value" => "test",
      "onChange" => %{
        "action" => 10,
        "props" => ""
      }
    }

    assert {:error,
            [
              {"Type mismatch. Expected String but got Integer.", "/onChange/action"},
              {"Type mismatch. Expected Object but got String.", "/onChange/props"}
            ]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalid textfield with invalid listener key" do
    json = %{
      "type" => "textfield",
      "value" => "test",
      "onClick" => %{
        "action" => 42,
        "props" => "machin"
      }
    }

    assert {:error,
            [
              {"Schema does not allow additional properties.", "/onClick"}
            ]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "valid textfield with empty value" do
    json = %{
      "type" => "textfield",
      "value" => ""
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end
end
