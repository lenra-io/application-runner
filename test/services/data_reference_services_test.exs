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
          refBy_id: inserted_user.id
        })
        |> Repo.transaction()

      %{refs: [ref | _tail]} =
        inserted_user
        |> Repo.preload(:refs)

      %{refBy: [ref_by | _tail]} =
        inserted_point
        |> Repo.preload(:refBy)

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
                 refBy_id: -1
               })
               |> Repo.transaction()
    end

    test "should return refBy error when id invalid", %{env_id: env_id} do
      {:ok, inserted_datastore_point} = Repo.insert(Datastore.new(env_id, %{name: "users"}))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_point.id, %{"name" => "toto"}))

      assert {:error, :inserted_reference, %{errors: [refBy_id: {"does not exist", _constraint}]},
              _changes_so_far} =
               DataReferencesServices.create(%{
                 refs_id: inserted_user.id,
                 refBy_id: -1
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
          refBy_id: inserted_point.id
        })
        |> Repo.transaction()

      assert {:error, :inserted_reference,
              %{errors: [refs_id: {"has already been taken", _constraint}]},
              _changes_so_far} =
               DataReferencesServices.create(%{
                 refs_id: inserted_user.id,
                 refBy_id: inserted_point.id
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
          refBy_id: inserted_user.id
        })
        |> Repo.transaction()

      {:ok, _deleted_ref} =
        DataReferencesServices.delete(%{refs: inserted_point.id, refBy: inserted_user.id})
        |> Repo.transaction()

      assert nil == Repo.get(DataReferences, inserted_reference.id)
    end
  end
end
