defmodule ApplicationRunner.JsonStorage.DataReferences do
  @moduledoc """
    The references schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.JsonStorage.{Data, DataReferences}

  @derive {Jason.Encoder, only: [:id, :refs_id, :ref_by_id]}
  schema "data_references" do
    belongs_to(:refs, Data)
    belongs_to(:ref_by, Data)

    timestamps()
  end

  def changeset(refs, params \\ %{}) do
    refs
    |> cast(params, [:refs_id, :ref_by_id])
    |> validate_required([:refs_id, :ref_by_id])
    |> foreign_key_constraint(:refs_id)
    |> foreign_key_constraint(:ref_by_id)
    |> unique_constraint([:refs_id, :ref_by_id], name: :data_references_refs_id_ref_by_id)
  end

  def new(params) do
    %DataReferences{}
    |> DataReferences.changeset(params)
  end
end
