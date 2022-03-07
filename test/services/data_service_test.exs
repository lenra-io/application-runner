defmodule ApplicationRunner.DataServiceTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{Data, DataService, Datastore, FakeLenraEvironement, Repo}

  setup do
    {:ok, environement} = Repo.insert(FakeLenraEvironement.new())
    {:ok, env_id: environement.id}
  end

  describe "DataService.create_1/1" do
    test "should create data if json valid", %{env_id: env_id} do
      {:ok, inserted_datastore} = Repo.insert(Datastore.new(env_id, "users"))

      {:ok, %{inserted_data: inserted_data}} =
        DataService.create(env_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      data = Repo.get(Data, inserted_data.id)

      assert data.datastore_id == inserted_datastore.id
      assert data.data == %{"name" => "toto"}
    end

    test "should create many data if params is list", %{env_id: env_id} do
      {:ok, inserted_datastore} = Repo.insert(Datastore.new(env_id, "users"))

      {:ok, %{inserted_data: [inserted_data_toto | [inserted_data_test | _else]]}} =
        DataService.create(env_id, [
          %{"table" => "users", "data" => %{"name" => "toto"}},
          %{"table" => "users", "data" => %{"name" => "test"}}
        ])

      data_toto = Repo.get(Data, inserted_data_toto.id)
      data_test = Repo.get(Data, inserted_data_test.id)

      assert data_toto.datastore_id == inserted_datastore.id
      assert data_toto.data == %{"name" => "toto"}
      assert data_test.datastore_id == inserted_datastore.id
      assert data_test.data == %{"name" => "test"}
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

      assert {:error, :json_format_invalid} =
               DataService.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
    end
  end

  describe "DataService.delete_1/1" do
    test "should delete data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

      {:ok, %{inserted_data: inserted_data}} =
        DataService.create(env_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      data = Repo.get(Data, inserted_data.id)

      DataService.delete(%{"id" => data.id})

      deleted_data = Repo.get(Data, inserted_data.id)

      assert deleted_data == nil
    end

    test "should return error id invalid", %{env_id: _env_id} do
      assert {:error, :data_not_found} = DataService.delete(%{"id" => -1})
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

      assert {:error, :json_format_invalid} = DataService.delete(%{"data" => %{"name" => "toto"}})
    end
  end

  describe "DataService.update_1/1" do
    test "should delete data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

      {:ok, %{inserted_data: inserted_data}} =
        DataService.create(env_id, %{"table" => "users", "data" => %{"name" => "toto"}})

      data = Repo.get(Data, inserted_data.id)

      DataService.update(%{"id" => data.id, "data" => %{"name" => "test"}})

      updated_data = Repo.get(Data, inserted_data.id)

      assert updated_data.data == %{"name" => "test"}
    end

    test "should return error id invalid", %{env_id: _env_id} do
      assert {:error, :data_not_found} = DataService.update(%{"id" => -1, "data" => %{}})
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, "users"))

      assert {:error, :json_format_invalid} = DataService.update(%{"data" => %{"name" => "toto"}})
    end
  end
end
