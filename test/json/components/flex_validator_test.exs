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

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "valid empty flex" do
    json = %{
      "type" => "flex",
      "children" => []
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "invalid flex type" do
    json = %{
      "type" => "flexes",
      "children" => []
    }

    assert {:error, [{"flexes is invalid. Should have been flex", "/type"}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
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
             ApplicationRunner.UIValidator.validate(json)
  end

  test "invalid flex with no children property" do
    json = %{
      "type" => "flex"
    }

    assert {:error, [{"Required property children was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end
end
