defmodule ApplicationRunner.DataServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{FakeLenraEnvironment, JsonStorage}

  alias ApplicationRunner.JsonStorage.{Data, DataReferences, Datastore}

  setup do
    {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())
    {:ok, env_id: environment.id}
  end

  describe "DataServices.create_1/1" do
    test "should create data if json valid", %{env_id: env_id} do
      {:ok, inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      data = Repo.get(Data, inserted_data.id)

      assert data.datastore_id == inserted_datastore.id
      assert data.data == %{"name" => "toto"}
    end

    test "should return error if json invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      assert {:error, :data, :json_format_invalid, _changes_so_far} =
               JsonStorage.create_data(env_id, %{
                 "datastore" => "users",
                 "test" => %{"name" => "toto"}
               })
    end

    test "should return error if env_id invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      assert {:error, :datastore, :datastore_not_found, _changes_so_far} =
               JsonStorage.create_data(-1, %{
                 "_datastore" => "users",
                 "name" => "toto"
               })
    end

    test "should return error if datastore name invalid", %{env_id: env_id} do
      assert {:error, :datastore, :datastore_not_found, _changes_so_far} =
               JsonStorage.create_data(env_id, %{
                 "_datastore" => "test",
                 "name" => "toto"
               })
    end

    test "should create reference if refs id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "score" => "10"
        })

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id]
        })

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_point.id, ref_by_id: inserted_data.id)
             )
    end

    test "should create 2 if give 2 refs_id", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "score" => "10"
        })

      {:ok, %{inserted_data: inserted_point_bis}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "score" => "12"
        })

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id, inserted_point_bis.id]
        })

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_point.id, ref_by_id: inserted_data.id)
             )

      assert !is_nil(
               Repo.get_by(DataReferences,
                 refs_id: inserted_point_bis.id,
                 ref_by_id: inserted_data.id
               )
             )
    end

    test "should create reference if refBy id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_user}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "score" => "10",
          "_refBy" => [inserted_user.id]
        })

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_data.id, ref_by_id: inserted_user.id)
             )
    end

    test "should create reference if refs and refBy id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_team}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "team", "name" => "test"})

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "scrore" => "10"
        })

      {:ok, %{inserted_data: inserted_user}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id],
          "_refBy" => [inserted_team.id]
        })

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_user.id, ref_by_id: inserted_team.id)
             )

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_point.id, ref_by_id: inserted_user.id)
             )
    end

    test "should return error if refs id invalid ", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      assert {:error, "inserted_refs_-1", %{errors: [refs_id: {"does not exist", _constraint}]},
              _change_so_far} =
               JsonStorage.create_data(env_id, %{
                 "_datastore" => "users",
                 "name" => "toto",
                 "_refs" => [-1]
               })
    end

    test "should return error if ref_by_id invalid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      assert {:error, "inserted_refBy_-1",
              %{errors: [ref_by_id: {"does not exist", _constraint}]},
              _change_so_far} =
               JsonStorage.create_data(env_id, %{
                 "_datastore" => "points",
                 "score" => "10",
                 "_refBy" => [-1]
               })
    end
  end

  describe "JsonStorage.delete_data/1" do
    test "should delete data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      data = Repo.get(Data, inserted_data.id)

      JsonStorage.delete_data(env_id, data.id)

      deleted_data = Repo.get(Data, inserted_data.id)

      assert deleted_data == nil
    end

    test "should NOT delete data if env_id is invalid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      data = Repo.get(Data, inserted_data.id)

      {:error, _, :data_not_found, _} = JsonStorage.delete_data(env_id + 1, data.id)

      deleted_data = Repo.get(Data, inserted_data.id)

      assert deleted_data != nil
    end

    test "should return error id invalid", %{env_id: env_id} do
      assert {:error, :data, :data_not_found, _changes_so_far} =
               JsonStorage.delete_data(env_id, -1)
    end

    test "should also remove refence but not referenced data", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_user}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refBy" => [inserted_user.id]
        })

      data = Repo.get(Data, inserted_user.id)

      assert false == is_nil(Repo.get_by(DataReferences, refs_id: inserted_point.id))

      JsonStorage.delete_data(env_id, data.id)

      deleted_data = Repo.get(Data, inserted_user.id)

      assert deleted_data == nil

      not_deleted_data = Repo.get(Data, inserted_point.id)

      assert not_deleted_data.id == inserted_point.id

      assert true == is_nil(Repo.get_by(DataReferences, refs_id: inserted_point.id))
    end
  end

  describe "JsonStorage.update__data/1" do
    test "should update data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      data = Repo.get(Data, inserted_data.id)

      JsonStorage.update_data(env_id, %{"_id" => data.id, "name" => "test"})

      updated_data = Repo.get(Data, inserted_data.id)

      assert updated_data.data == %{"name" => "test"}
    end

    test "should NOT update data if env_id is not valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{"_datastore" => "users", "name" => "toto"})

      data = Repo.get(Data, inserted_data.id)

      assert {:error, _, :data_not_found, _} =
               JsonStorage.update_data(env_id + 1, %{"_id" => data.id, "name" => "test"})

      updated_data = Repo.get(Data, inserted_data.id)

      assert updated_data.data == %{"name" => "toto"}
    end

    test "should return error id invalid", %{env_id: env_id} do
      assert {:error, :data, :data_not_found, _changes_so_far} =
               JsonStorage.update_data(env_id, %{"_id" => -1})
    end

    test "should also update refs on update", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "score" => "10"
        })

      {:ok, %{inserted_data: inserted_point_bis}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "score" => "12"
        })

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id]
        })

      {:ok, %{data: updated_data}} =
        JsonStorage.update_data(env_id, %{
          "_id" => inserted_data.id,
          "_refs" => [inserted_point_bis.id]
        })

      data = Repo.get(Data, updated_data.id) |> Repo.preload(:refs)

      assert 1 == length(data.refs)

      assert List.first(data.refs).id ==
               inserted_point_bis.id
    end

    test "should also update refBy on update", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_data}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto"
        })

      {:ok, %{inserted_data: inserted_data_bis}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "test"
        })

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "score" => "10",
          "_refBy" => [inserted_data.id]
        })

      {:ok, %{data: updated_data}} =
        JsonStorage.update_data(env_id, %{
          "_id" => inserted_point.id,
          "_refBy" => [inserted_data_bis.id]
        })

      data = Repo.get(Data, updated_data.id) |> Repo.preload(:ref_by)

      assert 1 == length(data.ref_by)

      assert List.first(data.ref_by).id ==
               inserted_data_bis.id
    end

    test "should also update refs and refBy on update", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_team}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "team",
          "name" => "team1"
        })

      {:ok, %{inserted_data: inserted_team_bis}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "team",
          "name" => "team2"
        })

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "name" => "10"
        })

      {:ok, %{inserted_data: inserted_point_bis}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "name" => "12"
        })

      {:ok, %{inserted_data: inserted_user}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id],
          "_refBy" => [inserted_team.id]
        })

      {:ok, %{data: updated_data}} =
        JsonStorage.update_data(env_id, %{
          "_id" => inserted_user.id,
          "_refs" => [inserted_point_bis.id],
          "_refBy" => [inserted_team_bis.id]
        })

      data = Repo.get(Data, updated_data.id) |> Repo.preload(:ref_by) |> Repo.preload(:refs)

      assert 1 == length(data.ref_by)

      assert List.first(data.ref_by).id ==
               inserted_team_bis.id

      assert 1 == length(data.refs)

      assert List.first(data.refs).id ==
               inserted_point_bis.id
    end

    test "should return error if update with invalid refs id", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "points",
          "name" => "10"
        })

      {:ok, %{inserted_data: inserted_user}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id]
        })

      {:error, :refs, :references_not_found, _change_so_far} =
        JsonStorage.update_data(env_id, %{
          "_id" => inserted_user.id,
          "_refs" => [-1]
        })
    end

    test "should return error if update with invalid ref_by id", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_team}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "team",
          "name" => "team1"
        })

      {:ok, %{inserted_data: inserted_user}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refBy" => [inserted_team.id]
        })

      {:error, :ref_by, :references_not_found, _change_so_far} =
        JsonStorage.update_data(env_id, %{
          "_id" => inserted_user.id,
          "_refBy" => [-1]
        })
    end

    test "should not update data if env_id not the same", %{env_id: env_id} do
      {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())

      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))

      {:ok, _inserted_datastore} =
        Repo.insert(Datastore.new(environment.id, %{"name" => "team2"}))

      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_team}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "team",
          "name" => "team1"
        })

      {:ok, %{inserted_data: inserted_team_bis}} =
        JsonStorage.create_data(environment.id, %{
          "_datastore" => "team2",
          "name" => "team2"
        })

      {:ok, %{inserted_data: inserted_user}} =
        JsonStorage.create_data(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refBy" => [inserted_team.id]
        })

      {:error, :ref_by, :references_not_found, _change_so_far} =
        JsonStorage.update_data(env_id, %{
          "_id" => inserted_user.id,
          "_refBy" => [inserted_team_bis.id]
        })
    end
  end
end
