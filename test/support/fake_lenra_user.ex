defmodule ApplicationRunner.FakeLenraUser do
  @moduledoc """
    The application schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.{
    UserData,
    FakeLenraUser
  }

  schema "users" do
    has_many(:user_datas, UserData, foreign_key: :user_id)
    timestamps()
  end

  def changeset(application, params \\ %{}) do
    application
    |> cast(params, [:id])
  end

  def new(params \\ %{}) do
    %FakeLenraUser{}
    |> changeset(params)
  end

  def update(app, params) do
    app
    |> changeset(params)
  end
end
