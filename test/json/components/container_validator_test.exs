defmodule ApplicationRunner.ContainerValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "container.schema.json" schema
  """

  test "valid container" do
    json = %{
      "type" => "container",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid container with border" do
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

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid container with borderRadius" do
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

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid container forgotten child" do
    json = %{
      "type" => "container"
    }

    assert {:error, [{"Required property child was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid container border" do
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

    assert {:error,
            [
              {"Type mismatch. Expected Number but got String.", "/border/bottom/width"},
              {"Type mismatch. Expected Number but got String.", "/border/left/width"},
              {"Type mismatch. Expected Number but got String.", "/border/right/width"},
              {"Type mismatch. Expected Number but got String.", "/border/top/width"}
            ]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end
end
