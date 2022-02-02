defmodule ApplicationRunner.QueryTest do
  use ExUnit.Case, async: false

  alias ApplicationRunner.{Data, Datastore, FakeLenraEvironement, Query, DataRaferences, Repo}

  setup do
    {:ok, inserted_environement} = Repo.insert(FakeLenraEvironement.new())
    %{environment_id: inserted_environement.id}
  end

  describe "Query.insert_1/1" do
    test "insert datastore if json valid", %{environment_id: environment_id} do
      {:ok, %{inserted_datastore: inserted_datastore}} =
        Query.create_table(environment_id, %{"name" => "users"})

      datastore = Repo.get(Datastore, inserted_datastore.id)

      assert datastore.name == "users"
    end

    test "return error if datastore json invalid", %{environment_id: environment_id} do
      assert {:error, :json_format_error} == Query.insert(environment_id, %{"test" => "users"})
    end

    test "insert data if json valid", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(environment_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      data = Repo.get(Data, inserted_data.id)

      assert data.data == %{"name" => "toto"}
    end

    test "insert list of data if json valid", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(environment_id, [
          %{"table" => "users", "data" => %{"name" => "toto"}},
          %{"table" => "users", "data" => %{"name" => "test"}}
        ])

      [inserted_data_one | [inserted_data_two | _tail]] = inserted_data
      data_one = Repo.get(Data, inserted_data_one.id)
      data_two = Repo.get(Data, inserted_data_two.id)

      assert data_one.data == %{"name" => "toto"}
      assert data_two.data == %{"name" => "test"}
    end

    test "return error if data json invalid", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})

      assert {:error, :json_format_error} ==
               Query.insert(environment_id, %{"table" => "users", "test" => %{"name" => "toto"}})
    end

    test "return error if json valid but datastore not found", %{environment_id: environment_id} do
      assert {:error, :datastore_not_found} ==
               Query.insert(environment_id, %{"table" => "users", "data" => %{"name" => "toto"}})
    end

    test "insert data with refBy", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})
      Query.create_table(environment_id, %{"name" => "score"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(environment_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      {:ok, %{inserted_data: inserted_data_ref, inserted_ref: [inserted_ref]}} =
        Query.insert(environment_id, %{
          "table" => "score",
          "data" => %{"point" => 2},
          "refBy" => [inserted_data.id]
        })

      data = Repo.get(Data, inserted_data.id)
      ref = Repo.get(DataRaferences, inserted_ref.id)
      data_ref = Repo.get(Data, inserted_data_ref.id)

      assert data.data == %{"name" => "toto"}
      assert ref.refs_id == inserted_data.id
      assert ref.refBy_id == inserted_data_ref.id
      assert data_ref.data == %{"point" => 2}
    end

    test "insert data with refs", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})
      Query.create_table(environment_id, %{"name" => "score"})

      {:ok, %{inserted_data: inserted_data_ref}} =
        Query.insert(environment_id, %{"table" => "score", "data" => %{"point" => 2}})

      {:ok, %{inserted_data: inserted_data, inserted_ref: [inserted_ref]}} =
        Query.insert(environment_id, %{
          "table" => "users",
          "data" => %{"name" => "toto"},
          "refs" => [inserted_data_ref.id]
        })

      data = Repo.get(Data, inserted_data.id)
      ref = Repo.get(DataRaferences, inserted_ref.id)
      data_ref = Repo.get(Data, inserted_data_ref.id)

      assert data_ref.data == %{"point" => 2}
      assert ref.refBy_id == inserted_data_ref.id
      assert ref.refs_id == inserted_data.id
      assert data.data == %{"name" => "toto"}
    end

    test "return error if ref not found", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})
      Query.create_table(environment_id, %{"name" => "points"})

      {:ok, %{inserted_data: inserted_ref}} =
        Query.insert(environment_id, %{
          "table" => "points",
          "data" => %{"point" => "12"}
        })

      {:ok, %{inserted_data: inserted_data, inserted_ref: inserted_data_ref}} =
        Query.insert(environment_id, %{
          "table" => "users",
          "data" => %{"name" => "toto"},
          "refs" => [inserted_ref.id, -1]
        })

      [head | tail] = inserted_data_ref
      assert head.refs_id == inserted_data.id
      assert head.refBy_id == inserted_ref.id
      assert tail == [{:error, :ref_not_found}]
    end
  end

  describe "Query.update_1/1" do
    test "update data", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(environment_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      data = Repo.get(Data, inserted_data.id)

      assert data.data == %{"name" => "toto"}

      Query.update(%{"id" => data.id, "data" => %{"name" => "test"}})

      data = Repo.get(Data, inserted_data.id)

      assert data.data == %{"name" => "test"}
    end

    test "return error if data id not found", %{environment_id: _environment_id} do
      res = Query.update(%{"id" => -1, "data" => %{"name" => "test"}})

      assert res == {:error, :data_not_found}
    end

    test "return error if json invalid", %{environment_id: _environment_id} do
      res = Query.update(%{"ib" => -1, "data" => %{"name" => "test"}})

      assert res == {:error, :json_format_error}
    end
  end

  describe "Query.delete_1/1" do
    test "delete data", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(environment_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      Query.delete(%{"id" => inserted_data.id})
      data = Repo.get(Data, inserted_data.id)

      assert data == nil
    end

    test "delete data with ref", %{environment_id: environment_id} do
      Query.create_table(environment_id, %{"name" => "users"})

      {:ok, %{inserted_data: test}} =
        Query.insert(environment_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      {:ok, %{inserted_data: refBy}} =
        Query.insert(environment_id, %{
          "table" => "users",
          "data" => %{"name" => "refs"},
          "refBy" => [test.id]
        })

      {:ok, %{inserted_data: refs}} =
        Query.insert(environment_id, %{
          "table" => "users",
          "data" => %{"name" => "refBy"},
          "refs" => [test.id]
        })

      Query.delete(%{"id" => test.id})
      data = Repo.get(Data, test.id)

      refs =
        Repo.get(Data, refs.id)
        |> Repo.preload([:refs, :refBy])

      refBy =
        Repo.get(Data, refBy.id)
        |> Repo.preload([:refs, :refBy])

      assert data == nil
      assert refs.refs == []
      assert refBy.refBy == []
    end

    test "return error if data id not found", %{environment_id: _environment_id} do
      res = Query.delete(%{"id" => -1})

      assert res == {:error, :data_not_found}
    end

    test "return error if json invalid", %{environment_id: _environment_id} do
      res = Query.delete(%{"ib" => 1})

      assert res == {:error, :json_format_error}
    end
  end

  #

  describe "Query.get_1/1" do
    # test "get all data from table should return list of data", %{environment_id: _environment_id} do
    #  {:ok, app} = Repo.insert(FakeLenraApplication.new())
    #  Query.create_table(app.id, %{"name" => "users"})
    #  Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user1"}})
    #  Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user2"}})
    #
    #  res = Query.get(app.id, %{"table" => "users"})
    #
    #  assert 2 == length(res)
    # end
    #
    # test "get all data from table with incorrect table name should return error", %{
    #  environment_id: environment_id
    # } do
    #  res = Query.get(environment_id, %{"table" => "1"})
    #
    #  assert {:error, :datastore_not_found} == res
    # end
    #
    # test "data by id in table should return list of data" do
    #  {:ok, app} = Repo.insert(FakeLenraApplication.new())
    #  Query.create_table(app.id, %{"name" => "users"})
    #
    #  {:ok, %{inserted_data: app_one}} =
    #    Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user1"}})
    #
    #  {:ok, %{inserted_data: app_two}} =
    #    Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user2"}})
    #
    #  res = Query.get(app.id, %{"table" => "users", "ids" => [app_one.id, app_two.id]})
    #
    #  assert 2 == length(res)
    # end
    #
    # test "data by id in table should error if table name incorrect", %{
    #  environment_id: environment_id
    # } do
    #  res = Query.get(environment_id, %{"table" => "1", "ids" => []})
    #
    #  assert res == {:error, :datastore_not_found}
    # end
    #
    # test "data by id in table should empty list if data id incorrect", %{
    #  environment_id: _environment_id
    # } do
    #  {:ok, app} = Repo.insert(FakeLenraApplication.new())
    #  Query.create_table(app.id, %{"name" => "users"})
    #  res = Query.get(app.id, %{"table" => "users", "ids" => [-1]})
    #
    #  assert res == []
    # end
    #
    # test "data by refBy in table should return a list", %{
    #  environment_id: _environment_id
    # } do
    #  {:ok, app} = Repo.insert(FakeLenraApplication.new())
    #  Query.create_table(app.id, %{"name" => "users"})
    #  Query.create_table(app.id, %{"name" => "score"})
    #
    #  {:ok, %{inserted_data: user}} =
    #    Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "test"}})
    #
    #  Query.insert(app.id, %{
    #    "table" => "score",
    #    "data" => %{"points" => 10},
    #    "refBy" => [user.id]
    #  })
    #
    #  Query.insert(app.id, %{
    #    "table" => "score",
    #    "data" => %{"points" => 12},
    #    "refBy" => [user.id]
    #  })
    #
    #  res = Query.get(app.id, %{"table" => "score", "refBy" => [user.id]})
    #
    #  assert 2 == length(res)
    # end
    #
    # test "data by refs in table should return a list", %{
    #  environment_id: _environment_id
    # } do
    #  {:ok, app} = Repo.insert(FakeLenraApplication.new())
    #  Query.create_table(app.id, %{"name" => "users"})
    #  Query.create_table(app.id, %{"name" => "score"})
    #
    #  {:ok, %{inserted_data: pts}} =
    #    Query.insert(app.id, %{
    #      "table" => "score",
    #      "data" => %{"points" => 10}
    #    })
    #
    #  {:ok, %{inserted_data: user}} =
    #    Query.insert(app.id, %{
    #      "table" => "users",
    #      "data" => %{"name" => "test"},
    #      "refs" => [pts.id]
    #    })
    #
    #  # IO.inspect(user |> @repo.preload([:refs, :refBy]))
    #  # IO.inspect(pts |> @repo.preload([:refs, :refBy]))
    #
    #  res = Query.get(app.id, %{"table" => "score", "refs" => [pts.id]})
    #
    #  IO.inspect(res)
    #
    #  assert 1 == length(res)
    # end
  end
end
