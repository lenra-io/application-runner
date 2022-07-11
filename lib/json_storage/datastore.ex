defmodule ApplicationRunner.JsonStorage.Datastore do
  @moduledoc """
    The datastore schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.Environment
  alias ApplicationRunner.JsonStorage.{Data, Datastore}

  @derive {Jason.Encoder, only: [:id, :environment_id, :name]}
  schema "datastores" do
    has_many(:data, Data)
    belongs_to(:environment, Environment)
    field(:name, :string)
    timestamps()
  end

  def changeset(datastore, params \\ %{}) do
    datastore
    |> cast(params, [:name])
    |> validate_required([:name, :environment_id])
    |> unique_constraint([:name, :environment_id], name: :datastores_name_application_id_index)
    |> foreign_key_constraint(:environment_id)
  end

  def new(environment_id, params) do
    %Datastore{environment_id: environment_id}
    |> Datastore.changeset(params)
  end

  def update(datastore, params) do
    datastore
    |> Datastore.changeset(params)
  end
end
