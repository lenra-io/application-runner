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
             ApplicationRunner.UIValidator.validate_and_build(ui)
  end

  test "A UI must have a root property" do
    ui = %{}

    assert {:error, [{"Required property root was not present.", ""}]} ==
             ApplicationRunner.UIValidator.validate_and_build(ui)
  end

  test "the root property of a UI have to be a component" do
    ui = %{
      "root" => "any"
    }

    assert {:error,
            [
              {"Type mismatch. Expected Component but got String.", "/root"}
            ]} ==
             ApplicationRunner.UIValidator.validate_and_build(ui)

    ui = %{
      "root" => %{}
    }

    assert {:error,
            [
              {"Type mismatch. Expected Component but got Object.", "/root"}
            ]} ==
             ApplicationRunner.UIValidator.validate_and_build(ui)
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
             ApplicationRunner.UIValidator.validate_and_build(ui)
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
             ApplicationRunner.UIValidator.validate_and_build(ui)
  end

  test "build_listener" do
    listener = %{
      "action" => "string",
      "props" => %{}
    }

    assert {:ok, %{"code" => _}} = ApplicationRunner.UIValidator.build_listener(listener)
  end

  test "build_listener without props" do
    listener = %{
      "action" => "string"
    }

    assert {:ok, %{"code" => _}} = ApplicationRunner.UIValidator.build_listener(listener)
  end

  test "build_listener with additional props" do
    listener = %{
      "action" => "string",
      "props" => %{},
      "additional" => "foo"
    }

    assert {:ok, %{"code" => _, "additional" => "foo"}} =
             ApplicationRunner.UIValidator.build_listener(listener)
  end

  test "build_listeners" do
    comp = %{
      "type" => "test",
      "onPressed" => %{
        "action" => "press",
        "props" => %{}
      },
      "onDrag" => %{
        "action" => "drag",
        "props" => %{}
      }
    }

    assert {:ok, %{"onPressed" => %{"code" => _}, "onDrag" => %{"code" => _}}} =
             ApplicationRunner.UIValidator.build_listeners(comp, ["onPressed", "onDrag"])
  end

  test "build_child" do
    comp = %{
      "type" => "test",
      "leftChild" => %{
        "type" => "text",
        "value" => "foo"
      },
      "rightChild" => %{
        "type" => "text",
        "value" => "bar"
      }
    }

    assert {:ok,
            %{
              "leftChild" => %{
                "type" => "text",
                "value" => "foo"
              },
              "rightChild" => %{
                "type" => "text",
                "value" => "bar"
              }
            }} =
             ApplicationRunner.UIValidator.validate_and_build_child_list(
               comp,
               [
                 "leftChild",
                 "rightChild"
               ],
               "/root"
             )
  end

  test "build_child incorrect child" do
    comp = %{
      "type" => "test",
      "leftChild" => %{
        "type" => "text"
      },
      "rightChild" => %{
        "type" => "text"
      }
    }

    assert {:error,
            [
              {"Required property value was not present.", "/root/leftChild"},
              {"Required property value was not present.", "/root/rightChild"}
            ]} =
             ApplicationRunner.UIValidator.validate_and_build_child_list(
               comp,
               ["leftChild", "rightChild"],
               "/root"
             )
  end

  test "build_child forgotten child" do
    comp = %{"type" => "test"}

    assert :ok ==
             ApplicationRunner.UIValidator.validate_and_build_child_list(
               comp,
               ["leftChild", "rightChild"],
               "/root"
             )
  end

  test "build_children" do
    comp = %{
      "type" => "test"
    }

    assert :ok ==
             ApplicationRunner.UIValidator.validate_and_build_children_list(
               comp,
               ["leftMenu", "rightMenu"],
               "/root"
             )
  end
end
