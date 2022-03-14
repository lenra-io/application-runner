defmodule ApplicationRunner.UserDataServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{
    DataServices,
    Datastore,
    FakeLenraEnvironment,
    FakeLenraUser,
    UserData,
    UserDataServices
  }

  setup do
    {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())
    {:ok, user} = Repo.insert(FakeLenraUser.new())
    {:ok, env_id: environment.id, user_id: user.id}
  end

  describe "UserDataServices.create_1/1" do
    test "should create Userdata if params valid", %{env_id: env_id, user_id: user_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      {:ok, %{inserted_userdata: inserted_userdata}} =
        UserDataServices.create(%{user_id: user_id, data_id: inserted_data.id})
        |> Repo.transaction()

      userdata = Repo.get(UserData, inserted_userdata.id)

      assert userdata.user_id == user_id
      assert userdata.data_id == inserted_data.id
    end

    test "should return error if user_id invalid", %{env_id: env_id, user_id: _user_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      assert {:error, :inserted_userdata, %{errors: [user_id: {"does not exist", _constraint}]},
              _changes_so_far} =
               UserDataServices.create(%{user_id: -1, data_id: inserted_data.id})
               |> Repo.transaction()
    end

    test "should return error if data_id invalid", %{env_id: _env_id, user_id: user_id} do
      assert {:error, :inserted_userdata, %{errors: [data_id: {"does not exist", _cosntraint}]},
              _change_so_far} =
               UserDataServices.create(%{user_id: user_id, data_id: -1})
               |> Repo.transaction()
    end

    test "should create user_data if insert user_id twice but data_id are unique", %{
      env_id: env_id,
      user_id: user_id
    } do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data_two}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      {:ok, %{inserted_userdata: _inserted_userdata}} =
        UserDataServices.create(%{user_id: user_id, data_id: inserted_data.id})
        |> Repo.transaction()

      assert {:ok, %{inserted_userdata: _inserted_userdata}} =
               UserDataServices.create(%{user_id: user_id, data_id: inserted_data_two.id})
               |> Repo.transaction()
    end

    test "should create user_data if insert data_id twice but user_id are unique", %{
      env_id: env_id,
      user_id: user_id
    } do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      {:ok, user_two} = Repo.insert(FakeLenraUser.new())

      {:ok, %{inserted_userdata: _inserted_userdata}} =
        UserDataServices.create(%{user_id: user_id, data_id: inserted_data.id})
        |> Repo.transaction()

      assert {:ok, %{inserted_userdata: _inserted_userdata}} =
               UserDataServices.create(%{user_id: user_two.id, data_id: inserted_data.id})
               |> Repo.transaction()
    end

    test "should return error if inserte twice", %{env_id: env_id, user_id: user_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"datastore" => "users", "data" => %{"name" => "toto"}})
        |> Repo.transaction()

      {:ok, %{inserted_userdata: _inserted_userdata}} =
        UserDataServices.create(%{user_id: user_id, data_id: inserted_data.id})
        |> Repo.transaction()

      assert {:error, :inserted_userdata,
              %{
                errors: [
                  {:user_id, {"User are already link to this data", _constraint}}
                ]
              },
              _change_so_far} =
               UserDataServices.create(%{user_id: user_id, data_id: inserted_data.id})
               |> Repo.transaction()
    end
  end
end
