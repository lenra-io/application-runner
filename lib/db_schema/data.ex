defmodule ApplicationRunner.Data do
  @moduledoc """
    The datastore schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, Datastore, Refs}

  @derive {Jason.Encoder, only: [:id, :datastore_id, :data]}
  schema "data" do
    belongs_to(:datastore, Datastore)

    many_to_many(:referencers, Data,
      join_through: Refs,
      join_keys: [referencer_id: :id, referenced_id: :id]
    )

    many_to_many(:referenceds, Data,
      join_through: Refs,
      join_keys: [referenced_id: :id, referencer_id: :id]
    )

    field(:data, :map)

    timestamps()
  end

  def changeset(dataspace, params \\ %{}) do
    dataspace
    |> cast(params, [])
    |> validate_required([:data])
    |> foreign_key_constraint(:datastore_id)
    |> foreign_key_constraint(:referencers)
    |> foreign_key_constraint(:referenceds)
  end

  def new(datastore_id, data) do
    %Data{
      datastore_id: datastore_id,
      data: data
    }
    |> Data.changeset()
  end
end
