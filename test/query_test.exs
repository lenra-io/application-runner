defmodule ApplicationRunner.QueryTest do
  use ExUnit.Case, async: false

  alias ApplicationRunner.{Data, Datastore, FakeLenraApplication, Query, Refs, Repo}

  setup do
    {:ok, inserted_application} = Repo.insert(FakeLenraApplication.new())
    %{application_id: inserted_application.id}
  end

  describe "Query.insert_1/1" do
    test "insert datastore if json valid", %{application_id: application_id} do
      {:ok, %{inserted_datastore: inserted_datastore}} =
        Query.create_table(application_id, %{"name" => "users"})

      datastore = Repo.get(Datastore, inserted_datastore.id)

      assert datastore.name == "users"
    end

    test "return error if datastore json invalid", %{application_id: application_id} do
      assert {:error, :json_format_error} == Query.insert(application_id, %{"test" => "users"})
    end

    test "insert data if json valid", %{application_id: application_id} do
      Query.create_table(application_id, %{"name" => "users"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(application_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      data = Repo.get(Data, inserted_data.id)

      assert data.data == %{"name" => "toto"}
    end

    test "return error if data json invalid", %{application_id: application_id} do
      Query.create_table(application_id, %{"name" => "users"})

      assert {:error, :json_format_error} ==
               Query.insert(application_id, %{"table" => "users", "test" => %{"name" => "toto"}})
    end

    test "return error if json valid but datastore not found", %{application_id: application_id} do
      assert {:error, :datastore_not_found} ==
               Query.insert(application_id, %{"table" => "users", "data" => %{"name" => "toto"}})
    end

    test "insert data with refBy", %{application_id: application_id} do
      Query.create_table(application_id, %{"name" => "users"})
      Query.create_table(application_id, %{"name" => "score"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(application_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      {:ok, %{inserted_data: inserted_data_ref, inserted_ref: [inserted_ref]}} =
        Query.insert(application_id, %{
          "table" => "score",
          "data" => %{"point" => 2},
          "refBy" => [inserted_data.id]
        })

      data = Repo.get(Data, inserted_data.id)
      ref = Repo.get(Refs, inserted_ref.id)
      data_ref = Repo.get(Data, inserted_data_ref.id)

      assert data.data == %{"name" => "toto"}
      assert ref.referencer_id == inserted_data.id
      assert ref.referenced_id == inserted_data_ref.id
      assert data_ref.data == %{"point" => 2}
    end

    test "insert data with refTo", %{application_id: application_id} do
      Query.create_table(application_id, %{"name" => "users"})
      Query.create_table(application_id, %{"name" => "score"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(application_id, %{"table" => "score", "data" => %{"point" => 2}})

      {:ok, %{inserted_data: inserted_data_ref, inserted_ref: [inserted_ref]}} =
        Query.insert(application_id, %{
          "table" => "users",
          "data" => %{"name" => "toto"},
          "refTo" => [inserted_data.id]
        })

      data = Repo.get(Data, inserted_data.id)
      ref = Repo.get(Refs, inserted_ref.id)
      data_ref = Repo.get(Data, inserted_data_ref.id)

      assert data.data == %{"point" => 2}
      assert ref.referencer_id == inserted_data_ref.id
      assert ref.referenced_id == inserted_data.id
      assert data_ref.data == %{"name" => "toto"}
    end

    test "return error if ref not found", %{application_id: application_id} do
      Query.create_table(application_id, %{"name" => "users"})

      {:ok, inserted_data} =
        Query.insert(application_id, %{
          "table" => "users",
          "data" => %{"name" => "toto"},
          "refTo" => [1, 100]
        })

      [head | tail] = inserted_data.inserted_ref
      assert head.referencer_id == inserted_data.inserted_data.id
      assert head.referenced_id == 1
      assert tail == [{:error, :ref_not_found}]
    end
  end

  describe "Query.update_1/1" do
    test "update data", %{application_id: application_id} do
      Query.create_table(application_id, %{"name" => "users"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(application_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      data = Repo.get(Data, inserted_data.id)

      assert data.data == %{"name" => "toto"}

      Query.update(%{"id" => data.id, "data" => %{"name" => "test"}})

      data = Repo.get(Data, inserted_data.id)

      assert data.data == %{"name" => "test"}
    end

    test "return error if data id not found", %{application_id: _application_id} do
      res = Query.update(%{"id" => -1, "data" => %{"name" => "test"}})

      assert res == {:error, :data_not_found}
    end

    test "return error if json invalid", %{application_id: _application_id} do
      res = Query.update(%{"ib" => -1, "data" => %{"name" => "test"}})

      assert res == {:error, :json_format_error}
    end
  end

  describe "Query.delete_1/1" do
    test "delete data", %{application_id: application_id} do
      Query.create_table(application_id, %{"name" => "users"})

      {:ok, %{inserted_data: inserted_data}} =
        Query.insert(application_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      Query.delete(%{"id" => inserted_data.id})

      data = Repo.get(Data, inserted_data.id)

      assert data == nil
    end

    test "return error if data id not found", %{application_id: _application_id} do
      res = Query.delete(%{"id" => -1})

      assert res == {:error, :data_not_found}
    end

    test "return error if json invalid", %{application_id: _application_id} do
      res = Query.delete(%{"ib" => 1})

      assert res == {:error, :json_format_error}
    end
  end

  describe "Query.get_1/1" do
    test "get all data from table should return list of data", %{application_id: _application_id} do
      {:ok, app} = Repo.insert(FakeLenraApplication.new())
      Query.create_table(app.id, %{"name" => "users"})
      Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user1"}})
      Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user2"}})

      res = Query.get(app.id, %{"table" => "users"})

      assert 2 == length(res)
    end

    test "get all data from table with incorrect table name should return error", %{
      application_id: application_id
    } do
      res = Query.get(application_id, %{"table" => "1"})

      assert {:error, :datastore_not_found} == res
    end

    test "data by id in table should return list of data" do
      {:ok, app} = Repo.insert(FakeLenraApplication.new())
      Query.create_table(app.id, %{"name" => "users"})

      {:ok, %{inserted_data: app_one}} =
        Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user1"}})

      {:ok, %{inserted_data: app_two}} =
        Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "user2"}})

      res = Query.get(app.id, %{"table" => "users", "ids" => [app_one.id, app_two.id]})

      assert 2 == length(res)
    end

    test "data by id in table should error if table name incorrect", %{
      application_id: application_id
    } do
      res = Query.get(application_id, %{"table" => "1", "ids" => []})

      assert res == {:error, :datastore_not_found}
    end

    test "data by id in table should empty list if data id incorrect", %{
      application_id: _application_id
    } do
      {:ok, app} = Repo.insert(FakeLenraApplication.new())
      Query.create_table(app.id, %{"name" => "users"})
      res = Query.get(app.id, %{"table" => "users", "ids" => [-1]})

      assert res == []
    end

    test "data by refTo in table should return a list", %{
      application_id: _application_id
    } do
      {:ok, app} = Repo.insert(FakeLenraApplication.new())
      Query.create_table(app.id, %{"name" => "users"})
      Query.create_table(app.id, %{"name" => "score"})

      {:ok, %{inserted_data: user}} =
        Query.insert(app.id, %{"table" => "users", "data" => %{"name" => "test"}})

      Query.insert(app.id, %{
        "table" => "score",
        "data" => %{"points" => 10},
        "refBy" => [user.id]
      })

      Query.insert(app.id, %{
        "table" => "score",
        "data" => %{"points" => 12},
        "refBy" => [user.id]
      })

      res = Query.get(app.id, %{"table" => "score", "refBy" => [user.id]})

      assert 2 == length(res)
    end
  end
end
