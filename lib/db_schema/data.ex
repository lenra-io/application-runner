defmodule ApplicationRunner.Data do
  @moduledoc """
    The datastore schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, Datastore, DataRaferences}

  @derive {Jason.Encoder, only: [:id, :datastore_id, :data]}
  schema "data" do
    belongs_to(:datastore, Datastore)

    many_to_many(:refs, Data,
      join_through: DataRaferences,
      join_keys: [refs_id: :id, refBy_id: :id]
    )

    many_to_many(:refBy, Data,
      join_through: DataRaferences,
      join_keys: [refBy_id: :id, refs_id: :id]
    )

    field(:data, :map)

    timestamps()
  end

  def changeset(dataspace, params \\ %{}) do
    dataspace
    |> cast(params, [])
    |> validate_required([:data])
    |> foreign_key_constraint(:datastore_id)
    |> foreign_key_constraint(:refs)
    |> foreign_key_constraint(:refBy_id)
  end

  def new(datastore_id, data) do
    %Data{
      datastore_id: datastore_id,
      data: data
    }
    |> Data.changeset()
  end
end
