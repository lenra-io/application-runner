defmodule ApplicationRunner.TextValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "text.schema.json" schema
  """

  test "valide text component" do
    json = %{
      "type" => "text",
      "value" => "Txt test"
    }

    assert {:ok,
            %{
              "type" => "text",
              "value" => "Txt test"
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "/root")
  end

  test "valide text empty value" do
    json = %{
      "type" => "text",
      "value" => ""
    }

    assert {:ok,
            %{
              "type" => "text",
              "value" => ""
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalide text type" do
    json = %{
      "type" => "texts",
      "value" => ""
    }

    assert {:error, [{"Invalid component type", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid text no value" do
    json = %{
      "type" => "text"
    }

    assert {:error, [{"Required property value was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid text no string value type" do
    json = %{
      "type" => "text",
      "value" => 42
    }

    assert {:error, [{"Type mismatch. Expected String but got Integer.", "/value"}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end
end
