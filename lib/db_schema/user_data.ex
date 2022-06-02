defmodule ApplicationRunner.UserData do
  @moduledoc """
    The userdata schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, User, UserData}

  @derive {Jason.Encoder, only: [:id, :user_id, :data_id]}
  schema "user_datas" do
    belongs_to(:user, User)
    belongs_to(:data, Data)

    timestamps()
  end

  def changeset(refs, params \\ %{}) do
    refs
    |> cast(params, [:user_id, :data_id])
    |> validate_required([:user_id, :data_id])
    |> unique_constraint([:user_id, :data_id],
      name: :user_datas_user_id_data_id,
      message: "This user is already linked to this data"
    )
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:data_id)
  end

  def new(params) do
    %UserData{}
    |> UserData.changeset(params)
  end
end
