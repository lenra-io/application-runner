defmodule ApplicationRunner.ATS.EctoParserTest do
  use ApplicationRunner.RepoCase

  alias ApplicationRunner.AST.{
    Parser,
    EctoParser
  }

  alias ApplicationRunner.{
    Repo,
    FakeLenraUser,
    FakeLenraEnvironment,
    DatastoreServices,
    UserDataServices,
    DataServices
  }

  setup_all do
    FakeLenraUser.new() |> Repo.insert()
    FakeLenraEnvironment.new() |> Repo.insert()

    DatastoreServices.create(1, %{"name" => "userData"}) |> Repo.transaction()
    DatastoreServices.create(1, %{"name" => "todoList"}) |> Repo.transaction()
    DatastoreServices.create(1, %{"name" => "todos"}) |> Repo.transaction()
    # 1
    DataServices.create(1, %{"datastore" => "userData", "data" => %{"score" => 42}})
    |> Repo.transaction()

    UserDataServices.create(%{user_id: 1, data_id: 1}) |> Repo.transaction()
    # 2
    DataServices.create(1, %{
      "datastore" => "todoList",
      "data" => %{"name" => "favorites"},
      "refBy" => [1]
    })
    |> Repo.transaction()

    # 3
    DataServices.create(1, %{
      "datastore" => "todoList",
      "data" => %{"name" => "not fav"},
      "refBy" => [1]
    })
    |> Repo.transaction()

    # 4
    DataServices.create(1, %{
      "datastore" => "todos",
      "data" => %{"title" => "Faire la vaisselle"},
      "refBy" => [2]
    })
    |> Repo.transaction()

    # 5
    DataServices.create(1, %{
      "datastore" => "todos",
      "data" => %{"title" => "Faire la cuisine"},
      "refBy" => [2]
    })
    |> Repo.transaction()

    # 6
    DataServices.create(1, %{
      "datastore" => "todos",
      "data" => %{"title" => "Faire le ménage", "nullField" => nil},
      "refBy" => [3]
    })
    |> Repo.transaction()
  end

  test "Base test, select all" do
    res =
      %{"$find" => %{}}
      |> Parser.from_json()
      |> EctoParser.to_ecto()
      |> Repo.all()

    assert Enum.count(res) == 6

    assert res |> Enum.map(fn e -> e.id end) |> MapSet.new() == MapSet.new([1, 2, 3, 4, 5, 6])
  end

  test "Select where datastore userData" do
    res =
      %{"$find" => %{"_datastore" => "userData"}}
      |> Parser.from_json()
      |> EctoParser.to_ecto()
      |> Repo.one()

    assert %ApplicationRunner.DataQueryView{
             data: %{
               "_data" => %{"score" => 42},
               "_datastore" => "userData",
               "_id" => 1,
               "_refBy" => [],
               "_refs" => [2, 3],
               "_user" => %{"email" => "test@lenra.io", "id" => 1}
             },
             id: 1
           } = res
  end

  test "Select where datastore Todo" do
    # null value in data should stay
    # Empty _refs/_refBy should return empty array

    res =
      %{"$find" => %{"_datastore" => "todos"}}
      |> Parser.from_json()
      |> EctoParser.to_ecto()
      |> Repo.all()

    assert Enum.count(res) == 3

    assert [
             %ApplicationRunner.DataQueryView{
               data: %{
                 "_data" => %{"title" => "Faire la cuisine"},
                 "_datastore" => "todos",
                 "_id" => 5,
                 "_refBy" => [2],
                 "_refs" => []
               },
               id: 5
             },
             %ApplicationRunner.DataQueryView{
               data: %{
                 "_data" => %{"nullField" => nil, "title" => "Faire le ménage"},
                 "_datastore" => "todos",
                 "_id" => 6,
                 "_refBy" => [3],
                 "_refs" => []
               },
               id: 6
             },
             %ApplicationRunner.DataQueryView{
               data: %{
                 "_data" => %{"title" => "Faire la vaisselle"},
                 "_datastore" => "todos",
                 "_id" => 4,
                 "_refBy" => [2],
                 "_refs" => []
               },
               id: 4
             }
           ] = res
  end

  test "Select with multi where" do
    res =
      %{"$find" => %{"_datastore" => "todos", "_id" => 4}}
      |> Parser.from_json()
      |> EctoParser.to_ecto()
      |> Repo.one()

    assert %ApplicationRunner.DataQueryView{
             data: %{
               "_data" => %{"title" => "Faire la vaisselle"},
               "_datastore" => "todos",
               "_id" => 4,
               "_refBy" => [2],
               "_refs" => []
             },
             id: 4
           } = res
  end
end
