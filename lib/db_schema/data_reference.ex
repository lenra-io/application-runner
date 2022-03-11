defmodule ApplicationRunner.DataReferences do
  @moduledoc """
    The references schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, DataReferences}

  @derive {Jason.Encoder, only: [:id, :refs_id, :refBy_id]}
  schema "data_references" do
    belongs_to(:refs, Data)
    belongs_to(:refBy, Data)

    timestamps()
  end

  def changeset(refs, params \\ %{}) do
    refs
    |> cast(params, [:refs_id, :refBy_id])
    |> validate_required([:refs_id, :refBy_id])
    |> foreign_key_constraint(:refs_id)
    |> foreign_key_constraint(:refBy_id)
    |> unique_constraint([:refs_id, :refBy_id], name: :data_references_refs_id_refBy_id)
  end

  def new(params) do
    %DataReferences{}
    |> DataReferences.changeset(params)
  end
end
