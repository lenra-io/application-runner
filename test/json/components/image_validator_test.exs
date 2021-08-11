defmodule ApplicationRunner.ImageValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "image_validator.schema.json" schema
  """

  @relative_path "components/image_validator.schema.json"

  test "Valid image" do
    json = %{
      "type" => "image",
      "path" => "download.jpeg"
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "Valid image with width and height properties set" do
    json = %{
      "type" => "image",
      "path" => "download.jpeg",
      "width" => 120.0,
      "height" => 120.0
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "Invalid type for image" do
    json = %{
      "type" => "images",
      "path" => "download.jpeg"
    }

    assert {:error, [{"Does not match pattern \"^image$\".", "/type"}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end

  test "Invalid image with no path" do
    json = %{
      "type" => "image"
    }

    assert {:error, [{"Required property path was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
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
             ApplicationRunner.UIValidator.validate_for_schema(json, @relative_path, "")
  end
end
