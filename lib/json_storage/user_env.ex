defmodule ApplicationRunner.Contract.UserEnv do
  @moduledoc """
    The user "contract" schema.
        This give ApplicationRunner an interface to match with the "real" user for both the Devtool and the Lenra server
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.JsonStorage.UserData

  @table_name Application.compile_env!(:application_runner, :lenra_user_table)
  schema @table_name do
    has_many(:user_datas, UserData, foreign_key: :user_id)
    field(:mongo_user_id, Ecto.UUID, autogenerate: true)
    timestamps()
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:email])
    |> validate_required([:email])
  end

  def embed(user) do
    user_map =
      if is_struct(user) do
        user |> Map.from_struct()
      else
        user
      end

    changeset =
      %__MODULE__{}
      |> cast(user_map, [:id, :email, :inserted_at, :updated_at])
      |> validate_required([:id, :email, :inserted_at, :updated_at])
      |> unique_constraint(:email)
      |> unique_constraint(:id)

    if changeset.valid? do
      Ecto.Changeset.apply_changes(changeset)
    else
      changeset
    end
  end

  def new(params) do
    %__MODULE__{}
    |> __MODULE__.changeset(params)
  end
end
