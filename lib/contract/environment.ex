defmodule ApplicationRunner.Contract.Environment do
  @moduledoc """
    The Environment "contract" schema.
    This give ApplicationRunner an interface to match with the "real" environment for both the Devtool and the Lenra server
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.JsonStorage.Datastore

  @type t :: %__MODULE__{}

  @table_name Application.compile_env!(:application_runner, :lenra_environment_table)
  schema @table_name do
    has_one(:datastore, Datastore, foreign_key: :environment_id)
    timestamps()
  end

  def changeset(environment, params \\ %{}) do
    environment
    |> cast(params, [])
  end

  def embed(environment) do
    environment_map =
      if is_struct(environment) do
        environment |> Map.from_struct()
      else
        environment
      end

    changeset =
      %__MODULE__{}
      |> cast(environment_map, [:id, :inserted_at, :updated_at])
      |> validate_required([:id, :inserted_at, :updated_at])
      |> unique_constraint(:id)

    if changeset.valid? do
      Ecto.Changeset.apply_changes(changeset)
    else
      changeset
    end
  end

  def new(params \\ %{}) do
    %__MODULE__{}
    |> __MODULE__.changeset(params)
  end
end