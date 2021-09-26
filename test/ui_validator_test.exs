defmodule ApplicationRunner.UIValidatorTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the `ApplicationRunner.UIValidator` module
  """

  @test_component_schema %{
    "$defs" => %{
      "listener" => %{
        "properties" => %{
          "action" => %{"type" => "string"},
          "props" => %{"type" => "object"}
        },
        "required" => ["action"],
        "type" => "listener"
      }
    },
    "$id" => "test.schema.json",
    "$schema" =>
      "https://raw.githubusercontent.com/lenra-io/ex_component_schema/beta/priv/static/draft-lenra.json",
    "additionalProperties" => false,
    "description" => "Element used to test the Lenra Draft",
    "properties" => %{
      "disabled" => %{
        "description" => "Whether the component should be disabled or not",
        "type" => "boolean"
      },
      "onDrag" => %{"$ref" => "#/$defs/listener"},
      "onPressed" => %{"$ref" => "#/$defs/listener"},
      "type" => %{"description" => "The type of the element", "enum" => ["test"]},
      "value" => %{
        "description" => "the value displayed in the element",
        "type" => "string"
      },
      "leftWidget" => %{"type" => "component"},
      "rightWidget" => %{"type" => "component"},
      "leftMenu" => %{"type" => "array", "items" => %{"type" => "component"}},
      "rightMenu" => %{"type" => "array", "items" => %{"type" => "component"}}
    },
    "required" => ["type", "value"],
    "title" => "Test Component",
    "type" => "component"
  }

  ApplicationRunner.JsonSchemata.load_raw_schema(@test_component_schema, "test")

  doctest ApplicationRunner.UIValidator

  test "valide basic UI" do
    ui = %{
      "root" => %{
        "type" => "text",
        "value" => "Txt test"
      }
    }

    assert {:ok, %{"type" => "text", "value" => "Txt test"}} ==
             ApplicationRunner.UIValidator.validate_and_build(ui)
  end

  test "A UI must have a root property" do
    ui = %{}

    assert {:error, [{"Required property root was not present.", "#"}]} ==
             ApplicationRunner.UIValidator.validate_and_build(ui)
  end

  test "the root property of a UI have to be a component" do
    ui = %{
      "root" => "any"
    }

    assert {:error,
            [
              {"Type mismatch. Expected Component but got String.", "#/root"}
            ]} ==
             ApplicationRunner.UIValidator.validate_and_build(ui)

    ui = %{
      "root" => %{}
    }

    assert {:error,
            [
              {"Type mismatch. Expected Component but got Object.", "#/root"}
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
               {"Type mismatch. Expected Component but got Object.", "/root/children/0"},
               {"Type mismatch. Expected Component but got Object.", "/root/children/1"}
             ]
           } ==
             ApplicationRunner.UIValidator.validate_and_build(ui)
  end

  test "build_listener should correctly build" do
    listener = %{
      "action" => "string",
      "props" => %{}
    }

    assert {:ok, %{"code" => _}} = ApplicationRunner.UIValidator.build_listener(listener)
  end

  test "build_listener without props should correctly build" do
    listener = %{
      "action" => "string"
    }

    assert {:ok, %{"code" => _}} = ApplicationRunner.UIValidator.build_listener(listener)
  end

  test "build_listener with additional props should correctly build" do
    listener = %{
      "action" => "string",
      "props" => %{},
      "additional" => "foo"
    }

    assert {:ok, %{"code" => _, "additional" => "foo"}} =
             ApplicationRunner.UIValidator.build_listener(listener)
  end

  test "build_listeners should correctly build" do
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

  test "build_listeners forgotten listeners" do
    comp = %{
      "type" => "test"
    }

    assert {:ok, %{}} =
             ApplicationRunner.UIValidator.build_listeners(comp, ["onPressed", "onDrag"])
  end

  test "build_listeners forgotten some listeners" do
    comp = %{
      "type" => "test",
      "onDrag" => %{
        "action" => "drag",
        "props" => %{}
      }
    }

    assert {:ok, %{"onDrag" => %{"code" => _}}} =
             ApplicationRunner.UIValidator.build_listeners(comp, ["onPressed", "onDrag"])
  end

  test "build_child_list should return the built children" do
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

  test "build_child incorrect child should return a list of errors" do
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

  test "build_child forgotten children should return an empty map" do
    comp = %{"type" => "test"}

    assert {:ok, %{}} ==
             ApplicationRunner.UIValidator.validate_and_build_child_list(
               comp,
               ["leftChild", "rightChild"],
               "/root"
             )
  end

  test "build_children" do
    comp = %{
      "type" => "test",
      "leftMenu" => [
        %{"type" => "text", "value" => "foo"}
      ],
      "rightMenu" => [
        %{"type" => "text", "value" => "bar"}
      ]
    }

    assert {:ok,
            %{
              "leftMenu" => [
                %{"type" => "text", "value" => "foo"}
              ],
              "rightMenu" => [
                %{"type" => "text", "value" => "bar"}
              ]
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_children_list(
               comp,
               ["leftMenu", "rightMenu"],
               "/root"
             )
  end

  test "build_children forgotten children should return empty map" do
    comp = %{
      "type" => "test"
    }

    assert {:ok, %{}} ==
             ApplicationRunner.UIValidator.validate_and_build_children_list(
               comp,
               ["leftMenu", "rightMenu"],
               "/root"
             )
  end

  test "build_children forgotten some children" do
    comp = %{
      "type" => "test",
      "leftMenu" => [
        %{"type" => "text", "value" => "foo"},
        %{"type" => "text", "value" => "bar"}
      ]
    }

    assert {:ok,
            %{
              "leftMenu" => [
                %{"type" => "text", "value" => "foo"},
                %{"type" => "text", "value" => "bar"}
              ]
            }} ==
             ApplicationRunner.UIValidator.validate_and_build_children_list(
               comp,
               ["leftMenu", "rightMenu"],
               "/root"
             )
  end

  test "build_component" do
    comp = %{
      "type" => "test",
      "value" => "foo",
      "onDrag" => %{
        "action" => "drag",
        "props" => %{}
      },
      "leftMenu" => [
        %{"type" => "text", "value" => "foo"},
        %{"type" => "text", "value" => "bar"}
      ]
    }

    assert {:ok,
            %{
              "type" => "test",
              "value" => "foo",
              "onDrag" => %{"code" => _},
              "leftMenu" => [
                %{"type" => "text", "value" => "foo"},
                %{"type" => "text", "value" => "bar"}
              ]
            }} = ApplicationRunner.UIValidator.validate_and_build_component(comp, "/root")
  end

  test "validate_and_build" do
    comp = %{
      "root" => %{
        "type" => "test",
        "value" => "foo",
        "onDrag" => %{
          "action" => "drag",
          "props" => %{}
        },
        "leftMenu" => [
          %{"type" => "text", "value" => "foo"},
          %{"type" => "text", "value" => "bar"}
        ]
      }
    }

    assert {:ok,
            %{
              "type" => "test",
              "value" => "foo",
              "onDrag" => %{"code" => _},
              "leftMenu" => [
                %{"type" => "text", "value" => "foo"},
                %{"type" => "text", "value" => "bar"}
              ]
            }} = ApplicationRunner.UIValidator.validate_and_build(comp)
  end

  test "complex ui errors should give correct paths to errors" do
    comp = %{
      "root" => %{
        "type" => "test",
        "value" => "foo",
        "leftMenu" => [
          %{
            "type" => "test",
            "value" => "first",
            "onPressed" => %{"action" => "first", "props" => %{}},
            "leftMenu" => [
              %{
                "type" => "test",
                "value" => "second",
                "leftMenu" => [
                  %{
                    "type" => "text",
                    "value" => 123
                  },
                  %{
                    "type" => "button"
                  }
                ]
              }
            ]
          },
          %{"type" => "text", "value" => "bar"}
        ]
      }
    }

    assert {:error,
            [
              {"Type mismatch. Expected String but got Integer.",
               "/root/leftMenu/0/leftMenu/0/leftMenu/0/value"},
              {"Required property text was not present.",
               "/root/leftMenu/0/leftMenu/0/leftMenu/1"}
            ]} == ApplicationRunner.UIValidator.validate_and_build(comp)
  end
end
