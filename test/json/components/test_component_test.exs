defmodule ApplicationRunner.TestComponentTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "test_component.schema.json" schema
  """
  @test_component_schema %{
    "$defs" => %{
      "listener" => %{
        "properties" => %{
          "action" => %{"type" => "string"},
          "props" => %{"type" => "object"}
        },
        "required" => ["action"],
        "type" => "listener"
      }
    },
    "$id" => "test_component.schema.json",
    "$schema" =>
      "https://raw.githubusercontent.com/lenra-io/ex_component_schema/beta/priv/static/draft-lenra.json",
    "additionalProperties" => false,
    "description" => "Element used to test the Lenra Draft",
    "properties" => %{
      "disabled" => %{
        "description" => "Whether the component should be disabled or not",
        "type" => "boolean"
      },
      "onDrag" => %{"$ref" => "#/$defs/listener"},
      "onPressed" => %{"$ref" => "#/$defs/listener"},
      "type" => %{"description" => "The type of the element", "enum" => ["test"]},
      "value" => %{
        "description" => "the value displayed in the element",
        "type" => "string"
      },
      "leftWidget" => %{"type" => "component"},
      "rightWidget" => %{"type" => "component"},
      "myChildren" => %{"type" => "array", "items" => %{"type" => "component"}}
    },
    "required" => ["type", "value"],
    "title" => "Test Component",
    "type" => "component"
  }

  test "property parsing" do
    expected = %{
      listeners: ["onDrag", "onPressed"],
      children: ["myChildren"],
      child: ["leftWidget", "rightWidget"]
    }

    res =
      @test_component_schema
      |> ExComponentSchema.Schema.resolve()
      |> ApplicationRunner.SchemaParser.parse()

    assert Enum.sort(Map.get(expected, :listeners)) == Enum.sort(Map.get(res, :listeners))
    assert Enum.sort(Map.get(expected, :children)) == Enum.sort(Map.get(res, :children))
    assert Enum.sort(Map.get(expected, :child)) == Enum.sort(Map.get(res, :child))
  end
end
