defmodule ApplicationRunner.UserDataServices do
  @moduledoc """
    The service that manages actions on data.
  """

  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.{
    Data,
    DataServices,
    Datastore,
    SessionState,
    UserData
  }

  @repo Application.compile_env!(:application_runner, :repo)

  def create(params), do: Ecto.Multi.new() |> create(params)

  def create(multi, params) do
    multi
    |> Ecto.Multi.insert(:inserted_user_data, fn _params ->
      UserData.new(params)
    end)
    |> @repo.transaction()
  end

  def create_with_data(%SessionState{env_id: env_id, user_id: user_id}) do
    Ecto.Multi.new()
    |> DataServices.create(env_id, %{"_datastore" => "_users"})
    |> Ecto.Multi.insert(:inserted_user_data, fn %{inserted_data: data} ->
      UserData.new(%{user_id: user_id, data_id: data.id})
    end)
    |> @repo.transaction()
  end

  def has_user_data?(%SessionState{env_id: env_id, user_id: user_id}) do
    env_id
    |> current_user_data_query(user_id)
    |> @repo.exists?()
  end

  def current_user_data_query(env_id, user_id) do
    from(
      ud in UserData,
      join: d in Data,
      on: d.id == ud.data_id,
      join: ds in Datastore,
      on: d.datastore_id == ds.id,
      where: ds.environment_id == ^env_id and ud.user_id == ^user_id,
      select: d
    )
  end
end
