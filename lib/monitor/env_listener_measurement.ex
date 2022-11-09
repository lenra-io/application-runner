defmodule ApplicationRunner.Monitor.EnvListenerMesureament do
  @moduledoc """
    ApplicationRunner.Monitor.SessionMeasurement is a ecto schema
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.Environment

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  schema "env_listener_measurement" do
    belongs_to(:environment, Environment)

    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)

    field(:duration, :integer)

    timestamps()
  end

  def changeset(listener_mesureament, params \\ %{}) do
    listener_mesureament
    |> cast(params, [:start_time, :end_time, :duration])
    |> validate_required([:start_time, :environment_id])
    |> foreign_key_constraint(:session_mesureament_uuid)
  end

  def new(environment_id, params \\ %{}) do
    %__MODULE__{environment_id: environment_id}
    |> __MODULE__.changeset(params)
  end

  def update(listener_mesureament, params) do
    listener_mesureament
    |> changeset(params)
  end
end