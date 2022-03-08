defmodule ApplicationRunner.DataReferenceServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{Data, DataReferencesServices, Datastore, FakeLenraEnvironment}

  setup do
    {:ok, environment} = Repo.insert(FakeLenraEnvironment.new())
    {:ok, env_id: environment.id}
  end

  describe "DataReferenceServices.create_1/1" do
    test "should create ref if json valid", %{env_id: env_id} do
      {:ok, inserted_datastore_user} = Repo.insert(Datastore.new(env_id, "users"))
      {:ok, inserted_datastore_point} = Repo.insert(Datastore.new(env_id, "points"))

      {:ok, inserted_user} =
        Repo.insert(Data.new(inserted_datastore_user.id, %{"name" => "toto"}))

      {:ok, inserted_point} = Repo.insert(Data.new(inserted_datastore_point.id, %{"score" => 10}))

      {:ok, %{inserted_reference: _inserted_reference}} =
        DataReferencesServices.create(%{
          refs: inserted_user.id,
          refBy: inserted_point.id
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
  end

  test "should return refs error when id invalid", %{env_id: _env_id} do
    assert {:error, :refs, :data_not_found, _change_sor_far} =
             DataReferencesServices.create(%{
               refs: -1,
               refBy: -1
             })
             |> Repo.transaction()
  end

  test "should return refBy error when id invalid", %{env_id: env_id} do
    {:ok, inserted_datastore_point} = Repo.insert(Datastore.new(env_id, "users"))

    {:ok, inserted_user} = Repo.insert(Data.new(inserted_datastore_point.id, %{"name" => "toto"}))

    assert {:error, :refBy, :data_not_found, _change_sor_far} =
             DataReferencesServices.create(%{
               refs: inserted_user.id,
               refBy: -1
             })
             |> Repo.transaction()
  end

  test "should return error if json invalid", %{env_id: _env_id} do
    assert {:error, :reference, :json_format_invalid, _change_sor_far} =
             DataReferencesServices.create(%{
               refs: -1,
               refsby: -1
             })
             |> Repo.transaction()
  end
end
