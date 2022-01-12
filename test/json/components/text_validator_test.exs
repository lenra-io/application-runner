defmodule ApplicationRunner.TextValidatorTest do
  use ApplicationRunner.ComponentCase

  @moduledoc """
    Test the "text.schema.json" schema
  """

  test "valide text component", %{session_state: session_state} do
    json = %{
      "type" => "text",
      "value" => "Txt test"
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "valide text empty value", %{session_state: session_state} do
    json = %{
      "type" => "text",
      "value" => ""
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "invalide text type", %{session_state: session_state} do
    json = %{
      "type" => "texts",
      "value" => ""
    }

    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Invalid component type", ""}]}, res)
  end

  test "invalid text no value", %{session_state: session_state} do
    json = %{
      "type" => "text"
    }

    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Required property value was not present.", ""}]}, res)
  end

  test "invalid text no string value type", %{session_state: session_state} do
    json = %{
      "type" => "text",
      "value" => 42
    }

    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Type mismatch. Expected String but got Integer.", "/value"}]}, res)
  end
end
