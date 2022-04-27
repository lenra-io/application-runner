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
        DataServices.create(env_id, %{"_datastore" => "users", "name" => "toto"})
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
                 "_datastore" => "users",
                 "name" => "toto"
               })
               |> Repo.transaction()
    end

    test "should return error if datastore name invalid", %{env_id: env_id} do
      assert {:error, :datastore, :datastore_not_found, _changes_so_far} =
               DataServices.create(env_id, %{
                 "_datastore" => "test",
                 "name" => "toto"
               })
               |> Repo.transaction()
    end

    test "should create reference if refs id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "score" => "10"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id]
        })
        |> Repo.transaction()

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_point.id, ref_by_id: inserted_data.id)
             )
    end

    test "should create 2 if give 2 refs_id", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "score" => "10"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point_bis}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "score" => "12"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id, inserted_point_bis.id]
        })
        |> Repo.transaction()

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
        DataServices.create(env_id, %{"_datastore" => "users", "name" => "toto"})
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "score" => "10",
          "_refBy" => [inserted_user.id]
        })
        |> Repo.transaction()

      assert !is_nil(
               Repo.get_by(DataReferences, refs_id: inserted_data.id, ref_by_id: inserted_user.id)
             )
    end

    test "should create reference if refs and refBy id is valid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_team}} =
        DataServices.create(env_id, %{"_datastore" => "team", "name" => "test"})
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "scrore" => "10"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id],
          "_refBy" => [inserted_team.id]
        })
        |> Repo.transaction()

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
               DataServices.create(env_id, %{
                 "_datastore" => "users",
                 "name" => "toto",
                 "_refs" => [-1]
               })
               |> Repo.transaction()
    end

    test "should return error if ref_by_id invalid", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      assert {:error, "inserted_refBy_-1",
              %{errors: [ref_by_id: {"does not exist", _constraint}]},
              _change_so_far} =
               DataServices.create(env_id, %{
                 "_datastore" => "points",
                 "score" => "10",
                 "_refBy" => [-1]
               })
               |> Repo.transaction()
    end
  end

  describe "DataServices.delete_1/1" do
    test "should delete data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"_datastore" => "users", "name" => "toto"})
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

    test "should also remove refence but not referenced data", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{"_datastore" => "users", "name" => "toto"})
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refBy" => [inserted_user.id]
        })
        |> Repo.transaction()

      data = Repo.get(Data, inserted_user.id)

      assert false == is_nil(Repo.get_by(DataReferences, refs_id: inserted_point.id))

      DataServices.delete(data.id)
      |> Repo.transaction()

      deleted_data = Repo.get(Data, inserted_user.id)

      assert deleted_data == nil

      not_deleted_data = Repo.get(Data, inserted_point.id)

      assert not_deleted_data.id == inserted_point.id

      assert true == is_nil(Repo.get_by(DataReferences, refs_id: inserted_point.id))
    end
  end

  describe "DataServices.update_1/1" do
    test "should update data if json valid", %{env_id: env_id} do
      Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{"_datastore" => "users", "name" => "toto"})
        |> Repo.transaction()

      data = Repo.get(Data, inserted_data.id)

      DataServices.update(%{"_id" => data.id, "name" => "test"})
      |> Repo.transaction()

      updated_data = Repo.get(Data, inserted_data.id)

      assert updated_data.data == %{"name" => "test"}
    end

    test "should return error id invalid", %{env_id: _env_id} do
      assert {:error, :data, :data_not_found, _changes_so_far} =
               DataServices.update(%{"_id" => -1})
               |> Repo.transaction()
    end

    test "should also update refs on update", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "score" => "10"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point_bis}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "score" => "12"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id]
        })
        |> Repo.transaction()

      {:ok, %{data: updated_data}} =
        DataServices.update(%{
          "_id" => inserted_data.id,
          "_refs" => [inserted_point_bis.id]
        })
        |> Repo.transaction()

      data = Repo.get(Data, updated_data.id) |> Repo.preload(:refs)

      assert 1 == length(data.refs)

      assert List.first(data.refs).id ==
               inserted_point_bis.id
    end

    test "should also update refBy on update", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "points"}))

      {:ok, %{inserted_data: inserted_data}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_data_bis}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "test"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "score" => "10",
          "_refBy" => [inserted_data.id]
        })
        |> Repo.transaction()

      {:ok, %{data: updated_data}} =
        DataServices.update(%{
          "_id" => inserted_point.id,
          "_refBy" => [inserted_data_bis.id]
        })
        |> Repo.transaction()

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
        DataServices.create(env_id, %{
          "_datastore" => "team",
          "name" => "team1"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_team_bis}} =
        DataServices.create(env_id, %{
          "_datastore" => "team",
          "name" => "team2"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "name" => "10"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_point_bis}} =
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "name" => "12"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id],
          "_refBy" => [inserted_team.id]
        })
        |> Repo.transaction()

      {:ok, %{data: updated_data}} =
        DataServices.update(%{
          "_id" => inserted_user.id,
          "_refs" => [inserted_point_bis.id],
          "_refBy" => [inserted_team_bis.id]
        })
        |> Repo.transaction()

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
        DataServices.create(env_id, %{
          "_datastore" => "points",
          "name" => "10"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refs" => [inserted_point.id]
        })
        |> Repo.transaction()

      {:error, :refs, :references_not_found, _change_so_far} =
        DataServices.update(%{
          "_id" => inserted_user.id,
          "_refs" => [-1]
        })
        |> Repo.transaction()
    end

    test "should return error if update with invalid ref_by id", %{env_id: env_id} do
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))
      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_team}} =
        DataServices.create(env_id, %{
          "_datastore" => "team",
          "name" => "team1"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refBy" => [inserted_team.id]
        })
        |> Repo.transaction()

      {:error, :ref_by, :references_not_found, _change_so_far} =
        DataServices.update(%{
          "_id" => inserted_user.id,
          "_refBy" => [-1]
        })
        |> Repo.transaction()
    end

    test "should not update data if env_id not the same", %{env_id: env_id} do
      {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())

      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "team"}))

      {:ok, _inserted_datastore} =
        Repo.insert(Datastore.new(environment.id, %{"name" => "team2"}))

      {:ok, _inserted_datastore} = Repo.insert(Datastore.new(env_id, %{"name" => "users"}))

      {:ok, %{inserted_data: inserted_team}} =
        DataServices.create(env_id, %{
          "_datastore" => "team",
          "name" => "team1"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_team_bis}} =
        DataServices.create(environment.id, %{
          "_datastore" => "team2",
          "name" => "team2"
        })
        |> Repo.transaction()

      {:ok, %{inserted_data: inserted_user}} =
        DataServices.create(env_id, %{
          "_datastore" => "users",
          "name" => "toto",
          "_refBy" => [inserted_team.id]
        })
        |> Repo.transaction()

      {:error, :ref_by, :references_not_found, _change_so_far} =
        DataServices.update(%{
          "_id" => inserted_user.id,
          "_refBy" => [inserted_team_bis.id]
        })
        |> Repo.transaction()
    end
  end
end
