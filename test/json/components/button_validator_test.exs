defmodule ApplicationRunner.ButtonValidatorTest do
  use ApplicationRunner.ComponentCase

  alias ApplicationRunner.{
    ApplicationRunnerAdapter,
    EnvManagers,
    SessionManagers
  }

  @moduledoc """
    Test the "button.schema.json" schema
  """

  test "valid button", %{session_id: session_id} do
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

    mock_root_and_run(json, session_id)

    assert_success(%{
      "onPressed" => %{"code" => "QaEIonDgErbXwK1vTqyhIOsm14ScEH3Kk/JGNBywBK4="},
      "text" => "",
      "type" => "button"
    })
  end

  test "valid button with no listener", %{session_id: session_id} do
    json = %{
      "type" => "button",
      "text" => "test"
    }

    # Setup mock
    mock_root_and_run(json, session_id)
    assert_success(%{"type" => "button", "text" => "test"})
  end

  test "invalid button type", %{session_id: session_id} do
    json = %{
      "type" => "buttons",
      "text" => "test"
    }

    # Setup mock
    mock_root_and_run(json, session_id)
    assert_error({:error, :invalid_ui, [{"Invalid component type", ""}]})
  end

  test "invalid button with no value", %{session_id: session_id} do
    json = %{
      "type" => "button"
    }

    # Setup mock
    mock_root_and_run(json, session_id)
    assert_error({:error, :invalid_ui, [{"Required property text was not present.", ""}]})
  end

  test "invalid button with invalid action and props in listener", %{session_id: session_id} do
    json = %{
      "type" => "button",
      "text" => "test",
      "onPressed" => %{
        "action" => 10,
        "props" => ""
      }
    }

    # Setup mock
    mock_root_and_run(json, session_id)

    assert_error(
      {:error, :invalid_ui,
       [
         {"Type mismatch. Expected String but got Integer.", "/onPressed/action"},
         {"Type mismatch. Expected Object but got String.", "/onPressed/props"}
       ]}
    )
  end

  test "invalid button with invalid listener key", %{session_id: session_id} do
    json = %{
      "type" => "button",
      "text" => "test",
      "onChange" => %{
        "action" => 42,
        "props" => "machin"
      }
    }

    # Setup mock
    mock_root_and_run(json, session_id)

    assert_error(
      {:error, :invalid_ui,
       [
         {"Schema does not allow additional properties.", "/onChange"}
       ]}
    )
  end

  test "valid button with empty text", %{session_id: session_id} do
    json = %{
      "type" => "button",
      "text" => ""
    }

    mock_root_and_run(json, session_id)
    assert_success(^json)
  end
end
