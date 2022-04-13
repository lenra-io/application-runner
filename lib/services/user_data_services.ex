defmodule ApplicationRunner.UserDataServices do
  @moduledoc """
    The service that manages actions on data.
  """

  alias ApplicationRunner.{UserData, DataServices}

  def create(params), do: Ecto.Multi.new() |> create(params)

  def create(multi, params) do
    multi
    |> Ecto.Multi.insert(:inserted_user_data, fn _params ->
      UserData.new(params)
    end)
  end

  def create_with_data(env_id, user_id) do
    Ecto.Multi.new()
    |> DataServices.create(env_id, %{"datastore" => "userData", "data" => %{}})
    |> Ecto.Multi.insert(:inserted_user_data, fn %{inserted_data: data} ->
      UserData.new(%{user_id: user_id, data_id: data.id})
    end)
  end
end
