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

  def delete(params), do: Ecto.Multi.new() |> delete(params)

  def delete(multi, params) do
    multi
    |> Ecto.Multi.run(
      :user_data,
      fn repo, _params ->
        case repo.get_by(UserData, params) do
          nil ->
            {:error, :user_data_not_found}

          datastore ->
            {:ok, datastore}
        end
      end
    )
    |> Ecto.Multi.delete(:deleted_user_data, fn %{user_data: %UserData{} = user_data} ->
      user_data
    end)
  end
end
