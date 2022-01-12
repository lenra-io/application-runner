defmodule ApplicationRunner.TextfieldValidatorTest do
  use ApplicationRunner.ComponentCase

  @moduledoc """
    Test the "textfield.schema.json" schema
  """

  test "valid textfield", %{session_state: session_state} do
    json = %{
      "type" => "textfield",
      "value" => "",
      "onChanged" => %{
        "action" => "anyaction",
        "props" => %{
          "number" => 10,
          "value" => "value"
        }
      }
    }

    res = mock_root_and_run(json, session_state)

    assert_success(
      %{
        "type" => "textfield",
        "value" => "",
        "onChanged" => %{
          "code" => _
        }
      },
      res
    )
  end

  test "valid textfield with no listener", %{session_state: session_state} do
    json = %{
      "type" => "textfield",
      "value" => "test"
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "invalid type textfield", %{session_state: session_state} do
    json = %{
      "type" => "textfields",
      "value" => "test"
    }

    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Invalid component type", ""}]}, res)
  end

  test "invalid textfield with no value", %{session_state: session_state} do
    json = %{
      "type" => "textfield"
    }

    res = mock_root_and_run(json, session_state)
    assert_error({:error, [{"Required property value was not present.", ""}]}, res)
  end

  test "invalid textfield with invalid action and props in listener", %{
    session_state: session_state
  } do
    json = %{
      "type" => "textfield",
      "value" => "test",
      "onChanged" => %{
        "action" => 10,
        "props" => ""
      }
    }

    res = mock_root_and_run(json, session_state)

    assert_error(
      {:error,
       [
         {"Type mismatch. Expected String but got Integer.", "/onChanged/action"},
         {"Type mismatch. Expected Object but got String.", "/onChanged/props"}
       ]},
      res
    )
  end

  test "invalid textfield with invalid listener key", %{session_state: session_state} do
    json = %{
      "type" => "textfield",
      "value" => "test",
      "onClick" => %{
        "action" => 42,
        "props" => "machin"
      }
    }

    res = mock_root_and_run(json, session_state)

    assert_error(
      {:error,
       [
         {"Schema does not allow additional properties.", "/onClick"}
       ]},
      res
    )
  end

  test "valid textfield with empty value", %{session_state: session_state} do
    json = %{
      "type" => "textfield",
      "value" => ""
    }

    res = mock_root_and_run(json, session_state)

    assert_success(
      %{
        "type" => "textfield",
        "value" => ""
      },
      res
    )
  end
end
