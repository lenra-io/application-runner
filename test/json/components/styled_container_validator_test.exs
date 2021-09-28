defmodule ApplicationRunner.StyledContainerValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the "styledContainer.schema.json" schema
  """

  test "valid styledContainer" do
    json = %{
      "type" => "styledContainer",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid styledContainer with border" do
    json = %{
      "type" => "styledContainer",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "border" => %{
        "top" => %{
          "width" => 2,
          "color" => "#FFFFFF"
        },
        "left" => %{
          "width" => 2,
          "color" => "#FFFFFF"
        },
        "bottom" => %{
          "width" => 2,
          "color" => "#FFFFFF"
        },
        "right" => %{
          "width" => 2,
          "color" => "#FFFFFF"
        }
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid styledContainer with borderRadius" do
    json = %{
      "type" => "styledContainer",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "borderRadius" => %{
        "topLeft" => %{"x" => 5.0, "y" => 5.0},
        "topRight" => %{"x" => 5.0, "y" => 5.0},
        "bottomLeft" => %{"x" => 5.0, "y" => 5.0},
        "bottomRight" => %{"x" => 5.0, "y" => 5.0}
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid styledContainer forgotten child" do
    json = %{
      "type" => "styledContainer"
    }

    assert {:error, [{"Required property child was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "invalid styledContainer border is invalid" do
    json = %{
      "type" => "styledContainer",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "border" => %{
        "top" => %{
          "width" => "invalid",
          "color" => "#FFFFFF"
        },
        "left" => %{
          "width" => "invalid",
          "color" => "#FFFFFF"
        },
        "bottom" => %{
          "width" => "invalid",
          "color" => "#FFFFFF"
        },
        "right" => %{
          "width" => "invalid",
          "color" => "#FFFFFF"
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
