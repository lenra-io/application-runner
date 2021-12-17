defmodule ApplicationRunner.Datastore do
  @moduledoc """
    The datastore schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{Datastore, Data}

  @application_schema Application.compile_env!(:application_runner, :lenra_application_schema)

  @derive {Jason.Encoder, only: [:id, :application_id, :name]}
  schema "datastores" do
    has_many(:data, Data)
    belongs_to(:application, @application_schema)
    field(:name, :string)
    timestamps()
  end

  def changeset(datastore, params \\ %{}) do
    datastore
    |> cast(params, [])
    |> validate_required([:name, :application_id])
    |> foreign_key_constraint(:application_id)
  end

  def new(application_id, name) do
    %Datastore{application_id: application_id, name: name}
    |> Datastore.changeset()
  end
end
