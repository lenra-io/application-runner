defmodule ApplicationRunner.DataRaferences do
  @moduledoc """
    The references schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, DataRaferences}

  @derive {Jason.Encoder, only: [:id, :refs_id, :refBy_id]}
  schema "data_references" do
    belongs_to(:refs, Data)
    belongs_to(:refBy, Data)

    timestamps()
  end

  def changeset(refs, params \\ %{}) do
    refs
    |> cast(params, [])
    |> validate_required([:refs_id, :refBy_id])
    |> foreign_key_constraint(:refs_id)
    |> foreign_key_constraint(:refBy_id)
  end

  def new(refs_id, refBy_id) do
    %DataRaferences{refBy_id: refBy_id, refs_id: refs_id}
    |> DataRaferences.changeset()
  end
end
