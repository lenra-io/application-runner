defmodule ApplicationRunner.Data do
  @moduledoc """
    The datastore schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Datastore, Data, Refs}

  schema "datas" do
    belongs_to(:datastore, Datastore)
    has_many(:referencer, Refs, foreign_key: :referencer_id)
    has_many(:referenced, Refs, foreign_key: :referenced_id)

    field(:data, :map)

    timestamps()
  end

  def changeset(dataspace, params \\ %{}) do
    dataspace
    |> cast(params, [])
    |> validate_required([:data])
    |> foreign_key_constraint(:datastore_id)
  end

  def new(datastore_id, data) do
    %Data{datastore_id: datastore_id, data: data}
    |> Data.changeset()
  end
end
