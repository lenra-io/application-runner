defmodule ApplicationRunner.ImageValidatorTest do
  use ApplicationRunner.ComponentCase

  @moduledoc """
    Test the "image.schema.json" schema
  """

  test "Valid image", %{session_state: session_state} do
    json = %{
      "type" => "image",
      "path" => "download.jpeg"
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "Valid image with width and height properties set", %{session_state: session_state} do
    json = %{
      "type" => "image",
      "path" => "download.jpeg",
      "width" => 120.0,
      "height" => 120.0
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "Invalid type for image", %{session_state: session_state} do
    json = %{
      "type" => "images",
      "path" => "download.jpeg"
    }

    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Invalid component type", ""}]}, res)
  end

  test "Invalid image with no path", %{session_state: session_state} do
    json = %{
      "type" => "image"
    }

    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Required property path was not present.", ""}]}, res)
  end

  test "Invalid image wrong types on width and height", %{session_state: session_state} do
    json = %{
      "type" => "image",
      "path" => "download.jpeg",
      "width" => "wrong",
      "height" => "wrong"
    }

    res = mock_root_and_run(json, session_state)

    assert_error(
      {:error,
       [
         {"Type mismatch. Expected Number but got String.", "/height"},
         {"Type mismatch. Expected Number but got String.", "/width"}
       ]},
      res
    )
  end
end
