defmodule ApplicationRunner.Monitor.SessionMeasurement do
  @moduledoc """
    ApplicationRunner.Monitor.SessionMeasurement is a ecto schema
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.{Environment, User}
  alias ApplicationRunner.Monitor.SessionListenerMesureament

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  schema "session_measurement" do
    belongs_to(:user, User)
    belongs_to(:environment, Environment)

    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)

    field(:duration, :integer)

    has_many(:listener_measurement, SessionListenerMesureament,
      foreign_key: :session_mesureament_uuid
    )

    timestamps()
  end

  def changeset(session_mesureament, params \\ %{}) do
    session_mesureament
    |> cast(params, [:start_time, :end_time, :duration])
    |> validate_required([:start_time, :environment_id, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:environment_id)
  end

  def new(env_id, user_id, params \\ %{}) do
    %__MODULE__{environment_id: env_id, user_id: user_id}
    |> __MODULE__.changeset(params)
  end

  def update(session_mesureament, params) do
    session_mesureament
    |> changeset(params)
  end
end
