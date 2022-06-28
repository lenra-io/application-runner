defmodule ApplicationRunner.FakeLenraUser do
  @moduledoc """
    The user schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.FakeLenraUser

  alias ApplicationRunner.JsonStorage.UserData

  schema "users" do
    has_many(:user_datas, UserData, foreign_key: :user_id)
    field(:email, :string)
    timestamps()
  end

  def changeset(application, params \\ %{}) do
    application
    |> cast(params, [:email])
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
