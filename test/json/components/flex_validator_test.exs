defmodule ApplicationRunner.FlexValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "flex.schema.json" schema
  """

  @relative_path "components/flex.schema.json"

  test "valid flex" do
    json = %{
      "type" => "flex",
      "children" => [
        %{
          "type" => "text",
          "value" => "Txt test"
        }
      ]
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid empty flex" do
    json = %{
      "type" => "flex",
      "children" => []
    }

    assert {:ok,
            %{
              "type" => "flex",
              "children" => []
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid flex type" do
    json = %{
      "type" => "flexes",
      "children" => []
    }

    assert {:error, [{"Invalid component type"}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalide component inside the flex" do
    json = %{
      "root" => %{
        "type" => "flex",
        "children" => [
          %{
            "type" => "text",
            "value" => "Txt test"
          },
          %{
            "type" => "New"
          }
        ]
      }
    }

    assert {:error, [{"Invalid type", "/root/children/1"}]} ==
             ApplicationRunner.UIValidator.validate_and_build(json)
  end

  test "invalid flex with no children property" do
    json = %{
      "type" => "flex"
    }

    assert {:error, [{"Required property children was not present.", "#"}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end
end
