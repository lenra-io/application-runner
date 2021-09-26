defmodule ApplicationRunner.ButtonValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "button.schema.json" schema
  """

  test "valid button" do
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

    assert {:ok,
            %{
              "type" => "button",
              "text" => "",
              "onPressed" => %{
                "code" => _
              }
            }} = ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid button with no listener" do
    json = %{
      "type" => "button",
      "text" => "test"
    }

    assert {:ok,
            %{
              "type" => "button",
              "text" => "test"
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid button type" do
    json = %{
      "type" => "buttons",
      "text" => "test"
    }

    assert {:error, [{"Invalid component type", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid button with no value" do
    json = %{
      "type" => "button"
    }

    assert {:error, [{"Required property text was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
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
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
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
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid button with empty text" do
    json = %{
      "type" => "button",
      "text" => ""
    }

    assert {:ok,
            %{
              "type" => "button",
              "text" => ""
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end
end
