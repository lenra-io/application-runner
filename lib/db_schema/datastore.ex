defmodule ApplicationRunner.Datastore do
  @moduledoc """
    The datastore schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Data, Datastore}

  @environment_schema Application.compile_env!(:application_runner, :lenra_environment_schema)

  @derive {Jason.Encoder, only: [:id, :environment_id, :name]}
  schema "datastores" do
    has_many(:data, Data)
    belongs_to(:environment, @environment_schema)
    field(:name, :string)
    timestamps()
  end

  def changeset(datastore, params \\ %{}) do
    datastore
    |> cast(params, [])
    |> validate_required([:name, :environment_id])
    |> unique_constraint([:name, :environment_id])
    |> foreign_key_constraint(:environment_id)
  end

  def new(environment_id, name) do
    %Datastore{environment_id: environment_id, name: name}
    |> Datastore.changeset()
  end
end
