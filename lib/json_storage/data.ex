defmodule ApplicationRunner.JsonStorage.Data do
  @moduledoc """
    The data schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.JsonStorage.{Data, DataReferences, Datastore}

  @derive {Jason.Encoder, only: [:id, :datastore_id, :data]}
  schema "datas" do
    belongs_to(:datastore, Datastore)

    many_to_many(:refs, Data,
      join_through: DataReferences,
      join_keys: [ref_by_id: :id, refs_id: :id],
      on_replace: :delete
    )

    many_to_many(:ref_by, Data,
      join_through: DataReferences,
      join_keys: [refs_id: :id, ref_by_id: :id],
      on_replace: :delete
    )

    field(:data, :map)

    timestamps()
  end

  def changeset(data, params \\ %{}) do
    data
    |> cast(params, [:data, :datastore_id])
    |> validate_required([:data, :datastore_id])
    |> foreign_key_constraint(:datastore_id)
    |> foreign_key_constraint(:refs)
    |> foreign_key_constraint(:ref_by_id)
  end

  def new(datastore_id, data) do
    %Data{
      datastore_id: datastore_id,
      data: data
    }
    |> Data.changeset()
  end

  def update(data, params) do
    data
    |> Data.changeset(params)
  end
end
