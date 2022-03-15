defmodule ApplicationRunner.DataServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{Data, DataReferences, DataServices, Datastore, FakeLenraEnvironment}

  setup do
    {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())
    {:ok, env_id: environment.id}
  end

  describe "DataServices.create_1/1" do
    test "should create data if json valid", %{env_id: env_id} do
      {:ok, inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      data = Repo.get(Data, inserted_data.id)

      assert data.datastore_id == inserted_datastore.id
      assert data.data == %{"name" => "toto"}
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      assert {:error, :data, :json_format_invalid, _changes_so_far} =
               DataServices.create(env_id, %{
                 "datastore" => "users",
                 "test" => %{"name" => "toto"}
               })
               |> Repo.transaction()
    end

    test "should return error if env_id invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      assert {:error, :datastore, :datastore_not_found, _changes_so_far} =
               DataServices.create(-1, %{
                 "datastore" => "users",
                 "data" => %{"name" => "toto"}
               })
               |> Repo.transaction()
    end

    test "should return error if datastore name invalid", %{env_id: env_id} do
      assert {:error, :datastore, :datastore_not_found, _changes_so_far} =
               DataServices.create(env_id, %{
                 "datastore" => "test",
                 "data" => %{"name" => "toto"}
               })
               |> Repo.transaction()
    end

    test "should create reference if refs id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "datastore" => "points",
          "data" => %{"score" => "10"}
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "datastore" => "users",
          "data" => %{"name" => "toto"},
          "refs" => [inserted_point.id]
        })
        |> Repo.transaction()

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_point.id, refBy_id: inserted_data.id)
             )
    end

    test "should create 2 if give 2 refs_id", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "datastore" => "points",
          "data" => %{"score" => "10"}
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point_bis}} =
        DataServices.create(env_id, %{
          "datastore" => "points",
          "data" => %{"score" => "12"}
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "datastore" => "users",
          "data" => %{"name" => "toto"},
          "refs" => [inserted_point.id, inserted_point_bis.id]
        })
        |> Repo.transaction()

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_point.id, refBy_id: inserted_data.id)
             )

      assert !is_nil(
               Repo.get_by(DataReferences,
                 refs_id: inserted_point_bis.id,
                 refBy_id: inserted_data.id
               )
             )
    end

    test "should create reference if refBy id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "datastore" => "points",
          "data" => %{"score" => "10"},
          "refBy" => [inserted_user.id]
        })
        |> Repo.transaction()

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_data.id, refBy_id: inserted_user.id)
             )
    end

    test "should create reference if refs and refBy id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_team}} =
        DataServices.create(env_id, %{"datastore" => "team", "data" => %{"name" => "test"}})
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "datastore" => "points",
          "data" => %{"scrore" => "10"}
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{
          "datastore" => "users",
          "data" => %{"name" => "toto"},
          "refs" => [inserted_point.id],
          "refBy" => [inserted_team.id]
        })
        |> Repo.transaction()

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_user.id, refBy_id: inserted_team.id)
             )

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_point.id, refBy_id: inserted_user.id)
             )
    end

    test "should return error if refs id invalid ", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      assert {:error, :"inserted_refs_-1", %{errors: [refs_id: {"does not exist", _constraint}]},
              _change_so_far} =
               DataServices.create(env_id, %{
                 "datastore" => "users",
                 "data" => %{"name" => "toto"},
                 "refs" => [-1]
               })
               |> Repo.transaction()
    end

    test "should return error if refBy_id invalid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      assert {:error, :"inserted_refBy_-1",
              %{errors: [refBy_id: {"does not exist", _constraint}]},
              _change_so_far} =
               DataServices.create(env_id, %{
                 "datastore" => "points",
                 "data" => %{"score" => "10"},
                 "refBy" => [-1]
               })
               |> Repo.transaction()
    end
  end

  describe "DataServices.delete_1/1" do
    test "should delete data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      data = Repo.get(Data, inserted_data.id)

      DataServices.delete(data.id)
      |> Repo.transaction()

      deleted_data = Repo.get(Data, inserted_data.id)

      assert deleted_data == nil
    end

    test "should return error id invalid", %{env_id: _env_id} do
      assert {:error, :data, :data_not_found, _changes_so_far} =
               DataServices.delete(-1)
               |> Repo.transaction()
    end
  end

  describe "DataServices.update_1/1" do
    test "should update data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      data = Repo.get(Data, inserted_data.id)

      DataServices.update(data.id, %{"data" => %{"name" => "test"}})
      |> Repo.transaction()

      updated_data = Repo.get(Data, inserted_data.id)

      assert updated_data.data == %{"name" => "test"}
    end

    test "should return error id invalid", %{env_id: _env_id} do
      assert {:error, :data, :data_not_found, _changes_so_far} =
               DataServices.update(-1, %{"data" => %{}})
               |> Repo.transaction()
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      assert {:error, :data, :json_format_invalid, _changes_so_far} =
               DataServices.update(-1, %{"datastore" => %{"name" => "toto"}})
               |> Repo.transaction()
    end
  end
end