defmodule ApplicationRunner.UserData do
  @moduledoc """
    The userdata schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, UserData}

  @environment_schema Application.compile_env!(:application_runner, :lenra_user_schema)

  @derive {Jason.Encoder, only: [:id, :refs_id, :refBy_id]}
  schema "user_datas" do
    belongs_to(:user, @environment_schema)
    belongs_to(:data, Data)

    timestamps()
  end

  def changeset(refs, params \\ %{}) do
    refs
    |> cast(params, [:user_id, :data_id])
    |> validate_required([:user_id, :data_id])
    |> unique_constraint([:user_id, :data_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:data_id)
  end

  def new(params) do
    %UserData{}
    |> UserData.changeset(params)
  end
end
