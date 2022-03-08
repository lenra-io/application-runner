defmodule ApplicationRunner.DatastoreServices do
  @moduledoc """
    The datastore service.
  """

  alias ApplicationRunner.Datastore

  def create(environment_id, op), do: Ecto.Multi.new() |> create(environment_id, op)

  def create(multi, environment_id, %{"name" => name}) do
    multi
    |> Ecto.Multi.insert(:inserted_datastore, Datastore.new(environment_id, name))
  end

  def create(multi, _app_id, _anything) do
    multi
    |> Ecto.Multi.run(:datastore, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end

  def update(datastore_id, op), do: Ecto.Multi.new() |> update(datastore_id, op)

  def update(multi, datastore_id, %{"name" => new_name}) do
    multi
    |> Ecto.Multi.run(
      :datastore,
      fn repo, _params ->
        case repo.get(Datastore, datastore_id) do
          nil ->
            {:error, :datastore_not_found}

          datastore ->
            {:ok, datastore}
        end
      end
    )
    |> Ecto.Multi.run(:inserted_datastore, fn repo, %{datastore: %Datastore{} = datastore} ->
      repo.update(Ecto.Changeset.change(datastore, name: new_name))
    end)
  end

  def update(multi, _app_id, _anything) do
    multi
    |> Ecto.Multi.run(:datastore, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end

  def delete(op), do: Ecto.Multi.new() |> delete(op)

  def delete(multi, datastore_id) do
    multi
    |> Ecto.Multi.run(
      :datastore,
      fn repo, _params ->
        case repo.get(Datastore, datastore_id) do
          nil ->
            {:error, :datastore_not_found}

          datastore ->
            {:ok, datastore}
        end
      end
    )
    |> Ecto.Multi.run(:inserted_datastore, fn repo, %{datastore: %Datastore{} = datastore} ->
      repo.delete(datastore)
    end)
  end
end
