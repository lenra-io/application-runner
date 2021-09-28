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

  test "valid styledContainer with simple border" do
    json = %{
      "type" => "styledContainer",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "border" => %{
        "all" => %{
          "width" => 2,
          "color" => "#FFFFFF"
        }
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid styledContainer with complex border" do
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
          "width" => 3,
          "color" => "#FFFFAA"
        },
        "bottom" => %{
          "width" => 4.0,
          "color" => "#FFFFBB"
        },
        "right" => %{
          "width" => 5.0,
          "color" => "#FFFFCC"
        }
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid styledContainer with simple borderRadius" do
    json = %{
      "type" => "styledContainer",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "borderRadius" => %{
        "circular" => 5.0
      }
    }

    assert {:ok, json} ==
             ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end

  test "valid styledContainer with complex borderRadius" do
    json = %{
      "type" => "styledContainer",
      "child" => %{
        "type" => "text",
        "value" => "foo"
      },
      "borderRadius" => %{
        "only" => %{
          "topLeft" => 2.0,
          "topRight" => 3,
          "bottomLeft" => 4.0,
          "bottomRight" => 5
        }
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
        "all" => %{
          "width" => "invalid",
          "color" => "#FFFFFF"
        }
      }
    }

    assert {:error, [{"Expected exactly one of the schemata to match, but none of them did.", "/border"}]} ==
      ApplicationRunner.UIValidator.validate_and_build_component(json, "")
  end
end
