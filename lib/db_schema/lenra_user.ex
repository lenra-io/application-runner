defmodule ApplicationRunner.User do
  @moduledoc """
    The embedded user schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.UserData

  embedded_schema do
    has_many(:user_datas, UserData, foreign_key: :user_id)
    field(:email, :string)
    timestamps()
  end

  def embede(user) do
    %ApplicationRunner.User{}
    |> cast(user, [:email])
    |> validate_required([:email])
  end
end
