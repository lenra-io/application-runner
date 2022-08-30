defmodule ApplicationRunner.Contract.UserEnv do
  @moduledoc """
    The user "contract" schema.
        This give ApplicationRunner an interface to match with the "real" user for both the Devtool and the Lenra server
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias ApplicationRunner.Contract.{Environment, User}

  @primary_key {:mongo_user_id, Ecto.UUID, autogenerate: true}
  schema "user_env" do
    belongs_to(:user, User)
    belongs_to(:environment, Environment)
    timestamps()
  end

  def changeset(user_env, params \\ %{}) do
    user_env
    |> cast(params, [:environment_id, :user_id])
    |> validate_required([])
  end

  def new(params) do
    %__MODULE__{}
    |> __MODULE__.changeset(params)
  end
end
