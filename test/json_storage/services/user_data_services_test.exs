defmodule ApplicationRunner.UserDataServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.JsonStorage

  alias ApplicationRunner.JsonStorage.{
    Datastore,
    UserData
  }

  alias ApplicationRunner.Contract.{Environment, User}

  setup do
    {:ok, environment} = Repo.insert(Environment.new())
    {:ok, user} = Repo.insert(User.new(%{email: "test@test.te"}))
    {:ok, env_id: environment.id, user_id: user.id}
  end

  describe "UserDataServices.create_1/1" do
    test "should create Userdata if params are valid", %{env_id: env_id, user_id: user_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      {:ok, %{inserted_user_data: inserted_user_data}} =
        JsonStorage.create_user_data(%{user_id: user_id, data_id: inserted_data.id})

      user_data = Repo.get(UserData, inserted_user_data.id)

      assert user_data.user_id == user_id
      assert user_data.data_id == inserted_data.id
    end

    test "should return an error if user_id is invalid", %{env_id: env_id, user_id: _user_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      assert {:error, :inserted_user_data, %{errors: [user_id: {"does not exist", _constraint}]},
              _changes_so_far} =
               JsonStorage.create_user_data(%{user_id: -1, data_id: inserted_data.id})
    end

    test "should return an error if data_id is invalid", %{env_id: _env_id, user_id: user_id} do
      assert {:error, :inserted_user_data, %{errors: [data_id: {"does not exist", _cosntraint}]},
              _change_so_far} = JsonStorage.create_user_data(%{user_id: user_id, data_id: -1})
    end

    test "should create 2 user_data if the same user_id is used and data_ids are not the same", %{
      env_id: env_id,
      user_id: user_id
    } do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      {:ok, %{inserted_data: inserted_data_two}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      {:ok, %{inserted_user_data: _inserted_user_data}} =
        JsonStorage.create_user_data(%{user_id: user_id, data_id: inserted_data.id})

      assert {:ok, %{inserted_user_data: _inserted_userdata}} =
               JsonStorage.create_user_data(%{user_id: user_id, data_id: inserted_data_two.id})
    end

    test "should create 2 user_data if different user_ids are used and data_ids are the same", %{
      env_id: env_id,
      user_id: user_id
    } do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      {:ok, user_two} = Repo.insert(User.new(%{email: "test@test.te"}))

      {:ok, %{inserted_user_data: _inserted_user_data}} =
        JsonStorage.create_user_data(%{user_id: user_id, data_id: inserted_data.id})

      assert {:ok, %{inserted_user_data: _inserted_user_data}} =
               JsonStorage.create_user_data(%{user_id: user_two.id, data_id: inserted_data.id})
    end

    test "should return an error if the same insert is done twice", %{
      env_id: env_id,
      user_id: user_id
    } do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      {:ok, %{inserted_user_data: _inserted_user_data}} =
        JsonStorage.create_user_data(%{user_id: user_id, data_id: inserted_data.id})

      assert {:error, :inserted_user_data,
              %{
                errors: [
                  {:user_id, {"This user is already linked to this data", _constraint}}
                ]
              },
              _change_so_far} =
               JsonStorage.create_user_data(%{user_id: user_id, data_id: inserted_data.id})
    end
  end
end
