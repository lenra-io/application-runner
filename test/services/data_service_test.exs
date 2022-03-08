defmodule ApplicationRunner.DataServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{Data, DataServices, Datastore, FakeLenraEnvironment}

  setup do
    {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())
    {:ok, env_id: environment.id}
  end

  describe "DataServices.create_1/1" do
    test "should create data if json valid", %{env_id: env_id} do
      {:ok, inserted_datastore} = Repo.insert(Datastore.new(env_id, "users"))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      data = Repo.get(Data, inserted_data.id)

      assert data.datastore_id == inserted_datastore.id
      assert data.data == %{"name" => "toto"}
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

      assert {:error, :data, :json_format_invalid, _change_sor_far} =
               DataServices.create(env_id, %{
                 "datastore" => "users",
                 "test" => %{"name" => "toto"}
               })
               |> Repo.transaction()
    end
  end

  describe "DataServices.delete_1/1" do
    test "should delete data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

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
      assert {:error, :data, :data_not_found, _change_sor_far} =
               DataServices.delete(-1)
               |> Repo.transaction()
    end
  end

  describe "DataServices.update_1/1" do
    test "should delete data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

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
      assert {:error, :data, :data_not_found, _change_sor_far} =
               DataServices.update(-1, %{"data" => %{}})
               |> Repo.transaction()
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

      assert {:error, :data, :json_format_invalid, _change_sor_far} =
               DataServices.update(-1, %{"datastore" => %{"name" => "toto"}})
               |> Repo.transaction()
    end
  end
end
