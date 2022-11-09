defmodule ApplicationRunner.Monitor.SessionListenerMesureament do
  @moduledoc """
    ApplicationRunner.Monitor.SessionMeasurement is a ecto schema
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Monitor.SessionMeasurement

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  schema "session_listener_measurement" do
    belongs_to(:session_mesureament, SessionMeasurement,
      references: :uuid,
      foreign_key: :session_mesureament_uuid,
      type: :binary_id
    )

    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)

    field(:duration, :integer)

    timestamps()
  end

  def changeset(listener_mesureament, params \\ %{}) do
    listener_mesureament
    |> cast(params, [:start_time, :end_time, :duration])
    |> validate_required([:start_time, :session_mesureament_uuid])
    |> foreign_key_constraint(:session_mesureament_uuid)
  end

  def new(session_mesureament_id, params \\ %{}) do
    %__MODULE__{session_mesureament_uuid: session_mesureament_id}
    |> __MODULE__.changeset(params)
  end

  def update(listener_mesureament, params) do
    listener_mesureament
    |> changeset(params)
  end
end
