defmodule ApplicationRunner.Environment do
  @moduledoc """
    The application schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{
    Datastore,
    FakeLenraEnvironment
  }

  schema "environments" do
    has_one(:datastore, Datastore, foreign_key: :environment_id)
    timestamps()
  end

  def changeset(application, params \\ %{}) do
    application
    |> cast(params, [:id])
  end

  def new(params \\ %{}) do
    %FakeLenraEnvironment{}
    |> changeset(params)
  end

  def update(app, params) do
    app
    |> changeset(params)
  end
end
