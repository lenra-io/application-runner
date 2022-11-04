defmodule ApplicationRunner.Monitor.SessionMeasurement do
  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.{User, Environment}

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  schema "session_measurement" do
    belongs_to(:user, User)
    belongs_to(:environment, Environment)

    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)

    field(:duration, :integer)

    timestamps()
  end

  def changeset(user_env_access, params \\ %{}) do
    user_env_access
    |> cast(params, [:start_time, :end_time, :duration])
    |> validate_required([:start_time, :environment_id, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:environment_id)
  end

  def new(env_id, user_id, params \\ %{}) do
    %__MODULE__{environment_id: env_id, user_id: user_id}
    |> __MODULE__.changeset(params)
  end

  def update(app, params) do
    app
    |> changeset(params)
  end
end
