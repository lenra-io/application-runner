defmodule ApplicationRunner.Refs do
  @moduledoc """
    The references schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, Refs}

  @derive {Jason.Encoder, only: [:id, :referencer_id, :referenced_id]}
  schema "refs" do
    belongs_to(:referencer, Data)
    belongs_to(:referenced, Data)

    timestamps()
  end

  def changeset(refs, params \\ %{}) do
    refs
    |> cast(params, [])
    |> validate_required([:referencer_id, :referenced_id])
    |> foreign_key_constraint(:referencer_id)
    |> foreign_key_constraint(:referenced_id)
  end

  def new(referencer_id, referenced_id) do
    %Refs{referenced_id: referenced_id, referencer_id: referencer_id}
    |> Refs.changeset()
  end
end
