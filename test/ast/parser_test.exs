defmodule ApplicationRunner.AST.ParserTest do
  use ExUnit.Case

  @moduledoc """
    Test the `ApplicationRunner.AST.Parser` module
  """
  alias ApplicationRunner.AST

  test "simpliest parsing possible" do
    assert AST.Parser.from_json(%{
             "$find" => %{}
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.And{clauses: []}
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Simple equal clause in the find" do
    assert AST.Parser.from_json(%{
             "$find" => %{
               "_datastore" => "userData"
             }
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.Eq{
                 left: %AST.DataKey{key_path: ["_datastore"]},
                 right: %AST.StringValue{value: "userData"}
               }
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Multiple equal clauses in the find" do
    assert AST.Parser.from_json(%{
             "$find" => %{
               "_datastore" => "userData",
               "name" => "Jean Neige"
             }
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.And{
                 clauses: [
                   %AST.Eq{
                     left: %AST.DataKey{key_path: ["_datastore"]},
                     right: %AST.StringValue{value: "userData"}
                   },
                   %AST.Eq{
                     left: %AST.DataKey{key_path: ["name"]},
                     right: %AST.StringValue{value: "Jean Neige"}
                   }
                 ]
               }
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Explicit Equal and And" do
    assert AST.Parser.from_json(%{
             "$find" => %{
               "$and" => [
                 %{"_datastore" => %{"$eq" => "userData"}},
                 %{"name" => %{"$eq" => "Jean Neige"}}
               ]
             }
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.And{
                 clauses: [
                   %AST.Eq{
                     left: %AST.DataKey{key_path: ["_datastore"]},
                     right: %AST.StringValue{value: "userData"}
                   },
                   %AST.Eq{
                     left: %AST.DataKey{key_path: ["name"]},
                     right: %AST.StringValue{value: "Jean Neige"}
                   }
                 ]
               }
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Explicit And simplification" do
    assert AST.Parser.from_json(%{
             "$find" => %{
               "$and" => [
                 %{"_datastore" => %{"$eq" => "userData"}}
               ]
             }
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.Eq{
                 left: %AST.DataKey{key_path: ["_datastore"]},
                 right: %AST.StringValue{value: "userData"}
               }
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Find with number" do
    assert AST.Parser.from_json(%{
             "$find" => %{"_id" => 42}
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.Eq{
                 left: %AST.DataKey{key_path: ["_id"]},
                 right: %AST.NumberValue{value: 42}
               }
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Find with @me" do
    assert AST.Parser.from_json(%{
             "$find" => %{"_id" => "@me"}
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.Eq{
                 left: %AST.DataKey{key_path: ["_id"]},
                 right: %AST.MeRef{}
               }
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Find with list of number" do
    assert AST.Parser.from_json(%{
             "$find" => %{"_refs" => [1, 2, 3]}
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.Eq{
                 left: %AST.DataKey{key_path: ["_refs"]},
                 right: %AST.ArrayValue{
                   values: [
                     %AST.NumberValue{value: 1},
                     %AST.NumberValue{value: 2},
                     %AST.NumberValue{value: 3}
                   ]
                 }
               }
             },
             select: %AST.Select{clause: nil}
           }
  end

  test "Overly complexe query with nested $and and array" do
    assert AST.Parser.from_json(%{
             "$find" => %{
               "_refs" => [1, 2, 3],
               "$and" => [
                 %{
                   "_refBy" => [1337],
                   "_truc" => %{"$eq" => ["a", "b"]}
                 },
                 %{"_score" => %{"$eq" => 42}}
               ]
             }
           }) == %AST.Query{
             find: %AST.Find{
               clause: %AST.And{
                 clauses: [
                   %AST.And{
                     clauses: [
                       %AST.And{
                         clauses: [
                           %AST.Eq{
                             left: %AST.DataKey{key_path: ["_refBy"]},
                             right: %AST.ArrayValue{
                               values: [
                                 %AST.NumberValue{value: 1337}
                               ]
                             }
                           },
                           %AST.Eq{
                             left: %AST.DataKey{key_path: ["_truc"]},
                             right: %AST.ArrayValue{
                               values: [
                                 %AST.StringValue{value: "a"},
                                 %AST.StringValue{value: "b"}
                               ]
                             }
                           }
                         ]
                       },
                       %AST.Eq{
                         left: %AST.DataKey{key_path: ["_score"]},
                         right: %AST.NumberValue{value: 42}
                       }
                     ]
                   },
                   %AST.Eq{
                     left: %AST.DataKey{key_path: ["_refs"]},
                     right: %AST.ArrayValue{
                       values: [
                         %AST.NumberValue{value: 1},
                         %AST.NumberValue{value: 2},
                         %AST.NumberValue{value: 3}
                       ]
                     }
                   }
                 ]
               }
             },
             select: %AST.Select{clause: nil}
           }
  end
end
