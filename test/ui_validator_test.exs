defmodule ApplicationRunner.UIValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the `ApplicationRunner.UIValidator` module
  """

  doctest ApplicationRunner.UIValidator

  test "valide basic UI" do
    ui = %{
      "root" => %{
        "type" => "text",
        "value" => "Txt test"
      }
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate(ui)
  end

  test "A UI must have a root property" do
    ui = %{}

    assert {:error, [{"Required property root was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate(ui)
  end

  test "the root property of a UI have to be a component" do
    ui = %{
      "root" => "any"
    }

    assert {:error,
            [
              {"Type mismatch. Expected Component but got String.", "/root"}
            ]} ==
             ApplicationRunner.UIValidator.validate(ui)

    ui = %{
      "root" => %{}
    }

    assert {:error,
            [
              {"Type mismatch. Expected Component but got Object.", "/root"}
            ]} ==
             ApplicationRunner.UIValidator.validate(ui)
  end

  test "bug LENRA-130" do
    ui = %{
      "root" => %{
        "type" => "flex",
        "children" => [
          %{
            "type" => "flex",
            "children" => [
              %{
                "type" => "textfield",
                "value" => "",
                "onChange" => %{
                  "name" => "Category.setName"
                }
              },
              %{
                "type" => "button",
                "text" => "Save",
                "onPressed" => %{
                  "name" => "Category.save"
                }
              }
            ]
          },
          %{
            "type" => "flex",
            "children" => [
              %{
                "type" => "button",
                "text" => "+",
                "onPressed" => %{
                  "name" => "Category.addField"
                }
              }
            ]
          }
        ]
      }
    }

    assert {
             :error,
             [
               {"Schema does not allow additional properties.",
                "/root/children/0/children/0/onChange/name"},
               {"Required property action was not present.",
                "/root/children/0/children/0/onChange"},
               {"Schema does not allow additional properties.",
                "/root/children/0/children/1/onPressed/name"},
               {"Required property action was not present.",
                "/root/children/0/children/1/onPressed"},
               {"Schema does not allow additional properties.",
                "/root/children/1/children/0/onPressed/name"},
               {"Required property action was not present.",
                "/root/children/1/children/0/onPressed"}
             ]
           } ==
             ApplicationRunner.UIValidator.validate(ui)
  end

  test "multiple type error" do
    ui = %{
      "root" => %{
        "type" => "flex",
        "children" => [
          %{"value" => "machin"},
          %{"value" => "truc"},
          %{"type" => "truc"},
          %{"type" => "machin"},
          %{"type" => "text"}
        ]
      }
    }

    assert {
             :error,
             [
               {"Type mismatch. Expected Component but got Object.", "/root/flex/children/0"},
               {"Type mismatch. Expected Component but got Object.", "/root/flex/children/1"}
             ]
           } ==
             ApplicationRunner.UIValidator.validate(ui)
  end
end
