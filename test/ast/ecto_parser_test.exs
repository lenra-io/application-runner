defmodule ApplicationRunner.ATS.EctoParserTest do
  use ApplicationRunner.RepoCase

  alias ApplicationRunner.AST.{
    EctoParser,
    Parser
  }

  alias ApplicationRunner.{
    DataServices,
    DatastoreServices,
    FakeLenraEnvironment,
    FakeLenraUser,
    Repo,
    UserDataServices
  }

  setup do
    {:ok, %{id: user_id}} = FakeLenraUser.new() |> Repo.insert()
    {:ok, %{id: env_id}} = FakeLenraEnvironment.new() |> Repo.insert()

    DatastoreServices.create(env_id, %{"name" => "_users"}) |> Repo.transaction()
    DatastoreServices.create(env_id, %{"name" => "todoList"}) |> Repo.transaction()
    DatastoreServices.create(env_id, %{"name" => "todos"}) |> Repo.transaction()
    # 1
    {:ok, %{inserted_data: %{id: user_data_id}}} =
      DataServices.create(env_id, %{"_datastore" => "_users", "score" => 42})
      |> Repo.transaction()

    UserDataServices.create(%{user_id: user_id, data_id: user_data_id}) |> Repo.transaction()
    # 2
    {:ok, %{inserted_data: %{id: todolist1_id}}} =
      DataServices.create(env_id, %{
        "_datastore" => "todoList",
        "name" => "favorites",
        "_refBy" => [user_data_id]
      })
      |> Repo.transaction()

    # 3
    {:ok, %{inserted_data: %{id: todolist2_id}}} =
      DataServices.create(env_id, %{
        "_datastore" => "todoList",
        "name" => "not fav",
        "_refBy" => [user_data_id]
      })
      |> Repo.transaction()

    # 4
    {:ok, %{inserted_data: %{id: todo1_id}}} =
      DataServices.create(env_id, %{
        "_datastore" => "todos",
        "title" => "Faire la vaisselle",
        "_refBy" => [todolist1_id]
      })
      |> Repo.transaction()

    # 5
    {:ok, %{inserted_data: %{id: todo2_id}}} =
      DataServices.create(env_id, %{
        "_datastore" => "todos",
        "title" => "Faire la cuisine",
        "_refBy" => [todolist1_id]
      })
      |> Repo.transaction()

    # 6
    {:ok, %{inserted_data: %{id: todo3_id}}} =
      DataServices.create(env_id, %{
        "_datastore" => "todos",
        "title" => "Faire le ménage",
        "nullField" => nil,
        "_refBy" => [todolist2_id]
      })
      |> Repo.transaction()

    {:ok,
     %{
       env_id: env_id,
       user_id: user_id,
       user_data_id: user_data_id,
       todolist1_id: todolist1_id,
       todolist2_id: todolist2_id,
       todo1_id: todo1_id,
       todo2_id: todo2_id,
       todo3_id: todo3_id
     }}
  end

  test "Base test, select all", %{
    user_data_id: user_data_id,
    todolist1_id: todolist1_id,
    todolist2_id: todolist2_id,
    todo1_id: todo1_id,
    todo2_id: todo2_id,
    todo3_id: todo3_id,
    env_id: env_id
  } do
    res =
      %{"$find" => %{}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.all()

    assert Enum.count(res) == 6

    assert res
           |> Enum.map(fn e -> e["_id"] end)
           |> MapSet.new() ==
             MapSet.new([user_data_id, todolist1_id, todolist2_id, todo1_id, todo2_id, todo3_id])
  end

  test "Select all wrong env_id", %{
    env_id: env_id,
    user_data_id: user_data_id
  } do
    res =
      %{"$find" => %{}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id + 1, user_data_id)
      |> Repo.all()

    assert Enum.empty?(res)
  end

  test "Select where datastore _users", %{
    user_id: user_id,
    user_data_id: user_data_id,
    todolist1_id: todolist1_id,
    todolist2_id: todolist2_id,
    env_id: env_id
  } do
    res =
      %{"$find" => %{"_datastore" => "_users"}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.one()

    assert %{
             "_data" => %{"score" => 42},
             "_datastore" => "_users",
             "_id" => ^user_data_id,
             "_refBy" => [],
             "_refs" => [^todolist1_id, ^todolist2_id],
             "_user" => %{"email" => "test@lenra.io", "id" => ^user_id}
           } = res
  end

  test "Select where datastore Todo", %{env_id: env_id, user_data_id: user_data_id} do
    res =
      %{"$find" => %{"_datastore" => "todos"}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.all()

    assert Enum.count(res) == 3
  end

  test "Select with multi where", %{
    todo3_id: todo3_id,
    env_id: env_id,
    user_data_id: user_data_id
  } do
    # null value in data should stay
    # Empty _refs/_refBy should return empty array

    res =
      %{"$find" => %{"_datastore" => "todos", "_id" => todo3_id}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.one()

    assert %{
             "_data" => %{"title" => "Faire le ménage", "nullField" => nil},
             "_refs" => []
           } = res
  end

  test "Select with where on list of number", %{
    todolist1_id: todolist1_id,
    todolist2_id: todolist2_id,
    env_id: env_id,
    user_data_id: user_data_id
  } do
    res =
      %{"$find" => %{"_refs" => [todolist1_id, todolist2_id]}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.one()

    assert %{
             "_data" => %{"score" => 42},
             "_datastore" => "_users",
             "_user" => %{"email" => "test@lenra.io"}
           } = res
  end

  test "Select with where on id with @me", %{
    user_data_id: user_data_id,
    env_id: env_id
  } do
    res =
      %{"$find" => %{"_id" => "@me"}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.one()

    assert %{
             "_data" => %{"score" => 42},
             "_datastore" => "_users",
             "_user" => %{"email" => "test@lenra.io"},
             "_id" => ^user_data_id,
             "_refBy" => []
           } = res
  end

  test "Select with where on number", %{
    user_data_id: user_data_id,
    env_id: env_id
  } do
    res =
      %{"$find" => %{"_id" => user_data_id}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.one()

    assert %{
             "_data" => %{"score" => 42},
             "_datastore" => "_users",
             "_user" => %{"email" => "test@lenra.io"},
             "_id" => ^user_data_id,
             "_refBy" => []
           } = res
  end

  test "Select with in", %{
    user_data_id: user_data_id,
    env_id: env_id
  } do
    res =
      %{
        "$find" => %{
          "$and" => [
            %{"_datastore" => "todos"},
            %{
              "_data" => %{
                "title" => %{
                  "$in" => ["Faire la vaisselle", "Faire la cuisine", "Faire la sieste"]
                }
              }
            }
          ]
        }
      }
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.all()

    assert length(res) == 2
  end

  test "Select with in dot", %{
    user_data_id: user_data_id,
    env_id: env_id
  } do
    res =
      %{
        "$find" => %{
          "$and" => [
            %{"_datastore" => "todos"},
            %{
              "_data.title" => %{
                "$in" => ["Faire la vaisselle", "Faire la cuisine", "Faire la sieste"]
              }
            }
          ]
        }
      }
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.all()

    assert length(res) == 2
  end

  test "Select with contains", %{
    user_data_id: user_data_id,
    env_id: env_id,
    todolist1_id: todolist1_id,
    todo1_id: todo1_id,
    todo2_id: todo2_id
  } do
    res =
      %{
        "$find" => %{
          "$and" => [
            %{"_datastore" => "todos"},
            %{
              "_refBy" => %{
                "$contains" => todolist1_id
              }
            }
          ]
        }
      }
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.all()

    [todo1 | [todo2 | _res]] = res
    # Get Todo1 & todo2
    ids = [todo1_id, todo2_id]
    assert length(res) == 2
    assert todo2["_id"] in ids
    assert todo1["_id"] in ids
  end

  test "Select with contains array", %{
    user_data_id: user_data_id,
    env_id: env_id,
    todolist1_id: todolist1_id,
    todolist2_id: todolist2_id,
    todo1_id: todo1_id,
    todo2_id: todo2_id,
    todo3_id: todo3_id
  } do
    res =
      %{
        "$find" => %{
          "$and" => [
            %{"_datastore" => "todos"},
            %{
              "_refBy" => %{
                "$contains" => [todolist1_id, todolist2_id]
              }
            }
          ]
        }
      }
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.all()

    [todo1 | [todo2 | [todo3 | _res]]] = res
    # Get Todo1 & todo2 & todo3
    ids = [todo1_id, todo2_id, todo3_id]
    assert length(res) == 3
    assert todo3["_id"] in ids
    assert todo2["_id"] in ids
    assert todo1["_id"] in ids
  end
end
