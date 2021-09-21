defmodule ApplicationRunner.ButtonValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "button.schema.json" schema
  """
  @relative_path "components/button.schema.json"

  test "valide button" do
    json = %{
      "type" => "button",
      "text" => "",
      "onPressed" => %{
        "action" => "anyaction",
        "props" => %{
          "number" => 10,
          "text" => "value"
        }
      }
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "valide button with no listener" do
    json = %{
      "type" => "button",
      "text" => "test"
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalide button type" do
    json = %{
      "type" => "buttons",
      "text" => "test"
    }

    assert {:error, [{"buttons is invalid. Should have been button", "/type"}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalid button with no value" do
    json = %{
      "type" => "button"
    }

    assert {:error, [{"Required property text was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalid button with invalid action and props in listener" do
    json = %{
      "type" => "button",
      "text" => "test",
      "onPressed" => %{
        "action" => 10,
        "props" => ""
      }
    }

    assert {:error,
            [
              {"Type mismatch. Expected String but got Integer.", "/onPressed/action"},
              {"Type mismatch. Expected Object but got String.", "/onPressed/props"}
            ]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalid button with invalid listener key" do
    json = %{
      "type" => "button",
      "text" => "test",
      "onChange" => %{
        "action" => 42,
        "props" => "machin"
      }
    }

    assert {:error,
            [
              {"Schema does not allow additional properties.", "/onChange"}
            ]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "valid button with empty text" do
    json = %{
      "type" => "button",
      "text" => ""
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end
end
