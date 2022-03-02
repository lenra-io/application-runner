defmodule ApplicationRunner.UserData do
  @moduledoc """
    The userdata schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, DataReferences}

  @environment_schema Application.compile_env!(:application_runner, :lenra_user_schema)

  @derive {Jason.Encoder, only: [:id, :refs_id, :refBy_id]}
  schema "user_datas" do
    belongs_to(:user_id, @environment_schema)
    belongs_to(:data_id, Data)

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
    %DataReferences{refBy_id: refBy_id, refs_id: refs_id}
    |> DataReferences.changeset()
  end
end
