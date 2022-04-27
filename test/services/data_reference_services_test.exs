defmodule ApplicationRunner.DataReferenceServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{
    Data,
    DataReferences,
    DataReferencesServices,
    Datastore,
    FakeLenraEnvironment
  }

  setup do
    {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())
    {:ok, env_id: environment.id}
  end

  describe "DataReferenceServices.create_1/1" do
    test "should create ref if params valid", %{env_id: env_id} do
      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, %{name: "users"}))
      {:ok, inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "points"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      {:ok, inserted_point} = Repo.insert(Data.new(inserted_datastore_point.id, %{"score" => 10}))

      {:ok, %{inserted_reference: _inserted_reference}} =
        DataReferencesServices.create(%{
          refs_id: inserted_point.id,
          ref_by_id: inserted_user.id
        })
        |> Repo.transaction()

      %{refs: [ref | _tail]} =
        inserted_user
        |> Repo.preload(:refs)

      %{ref_by: [ref_by | _tail]} =
        inserted_point
        |> Repo.preload(:ref_by)

      assert ref.id == inserted_point.id
      assert ref.data == %{"score" => 10}
      assert ref_by.id == inserted_user.id
      assert ref_by.data == %{"name" => "toto"}
    end

    test "should return refs error when id invalid", %{env_id: _env_id} do
      assert {:error, :inserted_reference, %{errors: [refs_id: {"does not exist", _constraint}]},
              _changes_so_far} =
               DataReferencesServices.create(%{
                 refs_id: -1,
                 ref_by_id: -1
               })
               |> Repo.transaction()
    end

    test "should return refBy error when id invalid", %{env_id: env_id} do
      {:ok, inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "users"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_point.id, %{"name" => "toto"}))

      assert {:error, :data_reference, :reference_not_found, _change_so_far} =
               DataReferencesServices.create(%{
                 refs_id: inserted_user.id,
                 ref_by_id: -1
               })
               |> Repo.transaction()
    end

    test "add same reference twice should return an error", %{env_id: env_id} do
      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, %{name: "users"}))
      {:ok, inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "points"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      {:ok, inserted_point} = Repo.insert(Data.new(inserted_datastore_point.id, %{"score" => 10}))

      {:ok, %{inserted_reference: _inserted_reference}} =
        DataReferencesServices.create(%{
          refs_id: inserted_user.id,
          ref_by_id: inserted_point.id
        })
        |> Repo.transaction()

      assert {:error, :inserted_reference, %{errors: [refs_id: {"has already been taken", _}]},
              _changes_so_far} =
               DataReferencesServices.create(%{
                 refs_id: inserted_user.id,
                 ref_by_id: inserted_point.id
               })
               |> Repo.transaction()
    end

    test "should return error if data not same env_id", %{env_id: env_id} do
      {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())

      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, %{name: "users"}))

      {:ok, inserted_datastore_point} =
        Repo.insert(Datastore.new(environment.id, %{name: "points"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      {:ok, inserted_point} = Repo.insert(Data.new(inserted_datastore_point.id, %{"score" => 10}))

      assert {:error, :data_reference, :reference_not_found, _change_so_far} =
               DataReferencesServices.create(%{
                 refs_id: inserted_user.id,
                 ref_by_id: inserted_point.id
               })
               |> Repo.transaction()
    end
  end

  describe "DataReferenceServices.delete_1/1" do
    test "should delete ref if json valid", %{env_id: env_id} do
      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, %{name: "users"}))
      {:ok, inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "points"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      {:ok, inserted_point} = Repo.insert(Data.new(inserted_datastore_point.id, %{"score" => 10}))

      {:ok, %{inserted_reference: inserted_reference}} =
        DataReferencesServices.create(%{
          refs_id: inserted_point.id,
          ref_by_id: inserted_user.id
        })
        |> Repo.transaction()

      {:ok, _deleted_ref} =
        DataReferencesServices.delete(%{refs_id: inserted_point.id, ref_by_id: inserted_user.id})
        |> Repo.transaction()

      assert nil == Repo.get(DataReferences, inserted_reference.id)
    end

    test "should return error if ref not found", %{env_id: env_id} do
      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, %{name: "users"}))
      {:ok, _inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "points"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      assert {:error, :reference, :reference_not_found, %{}} ==
               DataReferencesServices.delete(%{
                 refs_id: -1,
                 ref_by_id: inserted_user.id
               })
               |> Repo.transaction()
    end

    test "should return error if refBy not found", %{env_id: env_id} do
      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, %{name: "users"}))
      {:ok, _inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "points"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      {:error, :reference, :reference_not_found, %{}} =
        DataReferencesServices.delete(%{
          refs_id: inserted_user.id,
          ref_by_id: -1
        })
        |> Repo.transaction()
    end

    test "should return error if json key invalid ", %{env_id: env_id} do
      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, %{name: "users"}))
      {:ok, _inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "points"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      assert {:error, :reference, :json_format_invalid, %{}} ==
               DataReferencesServices.delete(%{
                 refs_id: inserted_user.id,
                 refsBy_id: -1
               })
               |> Repo.transaction()
    end
  end
end
