defmodule ApplicationRunner.JsonStorage.Services.Datastore do
  @moduledoc """
    The datastore service.
  """

  alias ApplicationRunner.JsonStorage.Datastore

  alias ApplicationRunner.Errors.TechnicalError

  @repo Application.compile_env!(:application_runner, :repo)

  def create(environment_id, params), do: Ecto.Multi.new() |> create(environment_id, params)

  def create(multi, environment_id, params) do
    multi
    |> Ecto.Multi.insert(:inserted_datastore, Datastore.new(environment_id, params))
    |> @repo.transaction()
  end

  def update(datastore_id, params), do: Ecto.Multi.new() |> update(datastore_id, params)

  def update(multi, datastore_id, params) do
    multi
    |> Ecto.Multi.run(
      :datastore,
      fn repo, _params ->
        case repo.get(Datastore, datastore_id) do
          nil ->
            TechnicalError.datastore_not_found_tuple()

          datastore ->
            {:ok, datastore}
        end
      end
    )
    |> Ecto.Multi.run(:updated_datastore, fn repo, %{datastore: %Datastore{} = datastore} ->
      repo.update(Datastore.update(datastore, params))
    end)
    |> @repo.transaction()
  end

  def delete(datastore_id), do: Ecto.Multi.new() |> delete(datastore_id)

  def delete(multi, datastore_id) do
    multi
    |> Ecto.Multi.run(
      :datastore,
      fn repo, _params ->
        case repo.get(Datastore, datastore_id) do
          nil ->
            TechnicalError.datastore_not_found_tuple()

          datastore ->
            {:ok, datastore}
        end
      end
    )
    |> Ecto.Multi.run(:deleted_datastore, fn repo, %{datastore: %Datastore{} = datastore} ->
      repo.delete(datastore)
    end)
    |> @repo.transaction()
  end
end