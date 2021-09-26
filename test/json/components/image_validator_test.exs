defmodule ApplicationRunner.ImageValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "image.schema.json" schema
  """

  test "Valid image" do
    json = %{
      "type" => "image",
      "path" => "download.jpeg"
    }

    assert {:ok,
            %{
              "type" => "image",
              "path" => "download.jpeg"
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "Valid image with width and height properties set" do
    json = %{
      "type" => "image",
      "path" => "download.jpeg",
      "width" => 120.0,
      "height" => 120.0
    }

    assert {:ok,
            %{
              "type" => "image",
              "path" => "download.jpeg",
              "width" => 120.0,
              "height" => 120.0
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "Invalid type for image" do
    json = %{
      "type" => "images",
      "path" => "download.jpeg"
    }

    assert {:error, [{"Invalid component type", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "Invalid image with no path" do
    json = %{
      "type" => "image"
    }

    assert {:error, [{"Required property path was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "Invalid image wrong types on width and height" do
    json = %{
      "type" => "image",
      "path" => "download.jpeg",
      "width" => "wrong",
      "height" => "wrong"
    }

    assert {:error,
            [
              {"Type mismatch. Expected Number but got String.", "/height"},
              {"Type mismatch. Expected Number but got String.", "/width"}
            ]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end
end
