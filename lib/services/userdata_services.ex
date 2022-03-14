defmodule ApplicationRunner.UserDataServices do
  @moduledoc """
    The service that manages actions on data.
  """

  alias ApplicationRunner.UserData

  def create(params), do: Ecto.Multi.new() |> create(params)

  def create(multi, params) do
    multi
    |> Ecto.Multi.insert(:inserted_user_data, fn _params ->
      UserData.new(params)
    end)
  end
end
