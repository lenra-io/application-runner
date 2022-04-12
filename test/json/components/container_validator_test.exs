defmodule ApplicationRunner.ContainerValidatorTest do
  use ApplicationRunner.ComponentCase

  alias ApplicationRunner.{
    ApplicationRunnerAdapter,
    EnvManagers,
    SessionManagers
  }

  @moduledoc """
    Test the "container.schema.json" schema
  """

  test "valid container", %{session_state: session_state} do
    json = %{
      "type" => "container",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      }
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "valid container with border", %{session_state: session_state} do
    json = %{
      "type" => "container",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "border" => %{
        "top" => %{
          "width" => 2,
          "color" => 0xFFFFFFFF
        },
        "left" => %{
          "width" => 2,
          "color" => 0xFFFFFFFF
        },
        "bottom" => %{
          "width" => 2,
          "color" => 0xFFFFFFFF
        },
        "right" => %{
          "width" => 2,
          "color" => 0xFFFFFFFF
        }
      }
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "valid container with borderRadius", %{session_state: session_state} do
    json = %{
      "type" => "container",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "decoration" => %{
        "borderRadius" => %{
          "topLeft" => %{"x" => 5.0, "y" => 5.0},
          "topRight" => %{"x" => 5.0, "y" => 5.0},
          "bottomLeft" => %{"x" => 5.0, "y" => 5.0},
          "bottomRight" => %{"x" => 5.0, "y" => 5.0}
        }
      }
    }

    res = mock_root_and_run(json, session_state)

    assert_success(^json, res)
  end

  test "invalid container forgotten child", %{session_state: session_state} do
    json = %{
      "type" => "container"
    }

    res = mock_root_and_run(json, session_state)

    assert_error({:error, :invalid_ui, [{"Required property child was not present.", ""}]}, res)
  end

  test "invalid container border", %{session_state: session_state} do
    json = %{
      "type" => "container",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "border" => %{
        "top" => %{
          "width" => "invalid",
          "color" => 0xFFFFFFFF
        },
        "left" => %{
          "width" => "invalid",
          "color" => 0xFFFFFFFF
        },
        "bottom" => %{
          "width" => "invalid",
          "color" => 0xFFFFFFFF
        },
        "right" => %{
          "width" => "invalid",
          "color" => 0xFFFFFFFF
        }
      }
    }

    res = mock_root_and_run(json, session_state)

    assert_error(
      {:error, :invalid_ui,
       [
         {"Type mismatch. Expected Number but got String.", "/border/bottom/width"},
         {"Type mismatch. Expected Number but got String.", "/border/left/width"},
         {"Type mismatch. Expected Number but got String.", "/border/right/width"},
         {"Type mismatch. Expected Number but got String.", "/border/top/width"}
       ]},
      res
    )
  end
end
