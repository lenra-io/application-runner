defmodule ApplicationRunner.DataServices do
  @moduledoc false

  alias ApplicationRunner.{Data, Datastore}

  def create(env_id, op), do: Ecto.Multi.new() |> create(env_id, op)

  def create(multi, environment_id, %{"datastore" => datastore, "data" => data}) do
    multi
    |> Ecto.Multi.run(:datastore, fn repo, _params ->
      case repo.get_by(Datastore, name: datastore, environment_id: environment_id) do
        nil ->
          {:error, :datastore_not_found}

        datastore ->
          {:ok, datastore}
      end
    end)
    |> Ecto.Multi.insert(:inserted_data, fn %{datastore: %Datastore{} = datastore} ->
      Data.new(datastore.id, data)
    end)
  end

  def create(multi, _environment_id, _invalid_json) do
    multi
    |> Ecto.Multi.run(:data, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end

  def update(op), do: Ecto.Multi.new() |> update(op)

  def update(multi, %{"id" => id, "data" => changes}) do
    multi
    |> Ecto.Multi.run(:data, fn repo, _params ->
      case repo.get(Data, id) do
        nil ->
          {:error, :data_not_found}

        data ->
          {:ok, data}
      end
    end)
    |> Ecto.Multi.update(:updated_data, fn %{data: %Data{} = data} ->
      data
      |> Ecto.Changeset.change(data: changes)
    end)
  end

  def update(multi, _invalid_json) do
    multi
    |> Ecto.Multi.run(:data, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end

  def delete(op), do: Ecto.Multi.new() |> delete(op)

  def delete(multi, %{"id" => id}) do
    multi
    |> Ecto.Multi.run(:data, fn repo, _ ->
      case repo.get(Data, id) do
        nil ->
          {:error, :data_not_found}

        data ->
          {:ok, data}
      end
    end)
    |> Ecto.Multi.delete(:deleted_data, fn %{data: %Data{} = data} ->
      data
    end)
  end

  def delete(multi, _invalid_json) do
    multi
    |> Ecto.Multi.run(:data, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end
end
