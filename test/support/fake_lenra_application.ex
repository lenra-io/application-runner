defmodule ApplicationRunner.FakeLenraApplication do
  @moduledoc """
    The application schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{
    Datastore,
    FakeLenraApplication
  }

  schema "applications" do
    has_one(:datastore, Datastore, foreign_key: :application_id)
    timestamps()
  end

  def changeset(application, params \\ %{}) do
    application
    |> cast(params, [])
  end

  def new(id) do
    %FakeLenraApplication{id: id}
    |> changeset()
  end

  def update(app, params) do
    app
    |> changeset(params)
  end
end
