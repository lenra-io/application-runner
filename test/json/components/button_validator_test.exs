defmodule ApplicationRunner.ButtonValidatorTest do
  use ApplicationRunner.ComponentCase

  alias ApplicationRunner.{
    ApplicationRunnerAdapter,
    EnvManager,
    EnvManagers,
    SessionManagers
  }

  @moduledoc """
    Test the "button.schema.json" schema
  """

  test "valid button", %{session_state: session_state} do
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

    # Setup mock
    res = mock_root_and_run(json, session_state)

    assert_success(
      %{"onPressed" => %{"code" => _}, "text" => "", "type" => "button"},
      res
    )
  end

  test "valid button with no listener", %{session_state: session_state} do
    json = %{
      "type" => "button",
      "text" => "test"
    }

    # Setup mock
    res = mock_root_and_run(json, session_state)
    assert_success(%{"type" => "button", "text" => "test"}, res)
  end

  test "invalid button type", %{session_state: session_state} do
    json = %{
      "type" => "buttons",
      "text" => "test"
    }

    # Setup mock
    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Invalid component type", ""}]}, res)
  end

  test "invalid button with no value", %{session_state: session_state} do
    json = %{
      "type" => "button"
    }

    # Setup mock
    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Required property text was not present.", ""}]}, res)
  end

  test "invalid button with invalid action and props in listener", %{session_state: session_state} do
    json = %{
      "type" => "button",
      "text" => "test",
      "onPressed" => %{
        "action" => 10,
        "props" => ""
      }
    }

    # Setup mock
    res = mock_root_and_run(json, session_state)

    assert_error(
      {:error,
       [
         {"Type mismatch. Expected String but got Integer.", "/onPressed/action"},
         {"Type mismatch. Expected Object but got String.", "/onPressed/props"}
       ]},
      res
    )
  end

  test "invalid button with invalid listener key", %{session_state: session_state} do
    json = %{
      "type" => "button",
      "text" => "test",
      "onChange" => %{
        "action" => 42,
        "props" => "machin"
      }
    }

    # Setup mock
    res = mock_root_and_run(json, session_state)

    assert_error(
      {:error,
       [
         {"Schema does not allow additional properties.", "/onChange"}
       ]},
      res
    )
  end

  test "valid button with empty text", %{session_state: session_state} do
    json = %{
      "type" => "button",
      "text" => ""
    }

    res = mock_root_and_run(json, session_state)
    assert_success(^json, res)
  end
end
