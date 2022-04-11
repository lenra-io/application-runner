defmodule ApplicationRunner.FlexValidatorTest do
  use ApplicationRunner.ComponentCase

  @moduledoc """
    Test the "flex.schema.json" schema
  """

  test "valid flex", %{session_state: session_state} do
    json = %{
      "type" => "flex",
      "children" => [
        %{
          "type" => "text",
          "value" => "Txt test"
        }
      ]
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "valid empty flex", %{session_state: session_state} do
    json = %{
      "type" => "flex",
      "children" => []
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "invalid flex type", %{session_state: session_state} do
    json = %{
      "type" => "flexes",
      "children" => []
    }

    res = mock_root_and_run(json, session_state)

    assert_error({:error, :invalid_ui, [{"Invalid component type", ""}]}, res)
  end

  test "invalide component inside the flex", %{session_state: session_state} do
    json = %{
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

    res = mock_root_and_run(json, session_state)

    assert_error({:error, :invalid_ui, [{"Invalid component type", "/children/1"}]}, res)
  end

  test "invalid flex with no children property", %{session_state: session_state} do
    json = %{
      "type" => "flex"
    }

    res = mock_root_and_run(json, session_state)

    assert_error(
      {:error, :invalid_ui, [{"Required property children was not present.", ""}]},
      res
    )
  end

  def my_widget(_, _) do
    %{
      "type" => "flex",
      "children" => []
    }
  end

  def root(_, _) do
    %{
      "type" => "widget",
      "name" => "myWidget"
    }
  end

  def init_data(_, _) do
    %{
      "type" => "widget",
      "name" => "myWidget"
    }
  end

  @tag mock: %{
         widgets: %{
           "myWidget" => &__MODULE__.my_widget/2,
           "root" => &__MODULE__.root/2
         },
         listeners: %{"InitData" => &__MODULE__.init_data/2}
       }
  test "valid flex with empty children in widget", %{
    session_state: _session_state,
    session_pid: session_pid
  } do
    ApplicationRunner.SessionManager.send_special_event(session_pid, "InitData", %{})

    refute_receive({:ui, _})
    refute_receive({:error, _})
  end
end
