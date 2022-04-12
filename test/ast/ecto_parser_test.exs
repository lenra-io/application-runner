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

    DatastoreServices.create(env_id, %{"name" => "userData"}) |> Repo.transaction()
    DatastoreServices.create(env_id, %{"name" => "todoList"}) |> Repo.transaction()
    DatastoreServices.create(env_id, %{"name" => "todos"}) |> Repo.transaction()
    # 1
    {:ok, %{inserted_data: %{id: user_data_id}}} =
      DataServices.create(env_id, %{"datastore" => "userData", "data" => %{"score" => 42}})
      |> Repo.transaction()

    UserDataServices.create(%{user_id: user_id, data_id: user_data_id}) |> Repo.transaction()
    # 2
    {:ok, %{inserted_data: %{id: todolist1_id}}} =
      DataServices.create(env_id, %{
        "datastore" => "todoList",
        "data" => %{"name" => "favorites"},
        "refBy" => [user_data_id]
      })
      |> Repo.transaction()

    # 3
    {:ok, %{inserted_data: %{id: todolist2_id}}} =
      DataServices.create(env_id, %{
        "datastore" => "todoList",
        "data" => %{"name" => "not fav"},
        "refBy" => [user_data_id]
      })
      |> Repo.transaction()

    # 4
    {:ok, %{inserted_data: %{id: todo1_id}}} =
      DataServices.create(env_id, %{
        "datastore" => "todos",
        "data" => %{"title" => "Faire la vaisselle"},
        "refBy" => [todolist1_id]
      })
      |> Repo.transaction()

    # 5
    {:ok, %{inserted_data: %{id: todo2_id}}} =
      DataServices.create(env_id, %{
        "datastore" => "todos",
        "data" => %{"title" => "Faire la cuisine"},
        "refBy" => [todolist1_id]
      })
      |> Repo.transaction()

    # 6
    {:ok, %{inserted_data: %{id: todo3_id}}} =
      DataServices.create(env_id, %{
        "datastore" => "todos",
        "data" => %{"title" => "Faire le ménage", "nullField" => nil},
        "refBy" => [todolist2_id]
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
           |> Enum.map(fn e -> e.id end)
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

  test "Select where datastore userData", %{
    user_id: user_id,
    user_data_id: user_data_id,
    todolist1_id: todolist1_id,
    todolist2_id: todolist2_id,
    env_id: env_id
  } do
    res =
      %{"$find" => %{"_datastore" => "userData"}}
      |> Parser.from_json()
      |> EctoParser.to_ecto(env_id, user_data_id)
      |> Repo.one()

    assert %ApplicationRunner.DataQueryView{
             data: %{
               "_data" => %{"score" => 42},
               "_datastore" => "userData",
               "_id" => ^user_data_id,
               "_refBy" => [],
               "_refs" => [^todolist1_id, ^todolist2_id],
               "_user" => %{"email" => "test@lenra.io", "id" => ^user_id}
             },
             id: ^user_data_id
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
           } = res.data
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

    assert %ApplicationRunner.DataQueryView{
             data: %{
               "_data" => %{"score" => 42},
               "_datastore" => "userData",
               "_user" => %{"email" => "test@lenra.io"}
             }
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

    assert %ApplicationRunner.DataQueryView{
             data: %{
               "_data" => %{"score" => 42},
               "_datastore" => "userData",
               "_user" => %{"email" => "test@lenra.io"},
               "_id" => ^user_data_id,
               "_refBy" => []
             },
             id: ^user_data_id
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

    assert %ApplicationRunner.DataQueryView{
             data: %{
               "_data" => %{"score" => 42},
               "_datastore" => "userData",
               "_user" => %{"email" => "test@lenra.io"},
               "_id" => ^user_data_id,
               "_refBy" => []
             },
             id: ^user_data_id
           } = res
  end
end
