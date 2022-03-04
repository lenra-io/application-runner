defmodule ApplicationRunner.DataService do
  @moduledoc false

  alias ApplicationRunner.{Data, Datastore}

  @repo Application.compile_env!(:application_runner, :repo)

  def create(environment_id, lists) when is_list(lists) do
    Enum.map(lists, fn list -> handle_create(environment_id, list) end)
  end

  def create(environment_id, data) do
    handle_create(environment_id, data)
  end

  def handle_create(environment_id, %{"table" => table, "data" => data}) do
    case @repo.get_by(Datastore, name: table, environment_id: environment_id) do
      nil ->
        {:error, :datastore_not_found}

      datastore ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:inserted_data, Data.new(datastore.id, data))
        |> @repo.transaction()
    end
  end

  def handle_create(_environment_id, _invalid_json) do
    {:error, :json_format_invalid}
  end

  def update(%{"id" => id, "data" => changes}) do
    case @repo.get(Data, id) do
      nil ->
        {:error, :data_not_found}

      data ->
        data
        |> Ecto.Changeset.change(data: changes)
        |> @repo.update()
    end
  end

  def update(_invalid_json) do
    {:error, :json_format_invalid}
  end

  def delete(%{"id" => id}) do
    case @repo.get(Data, id) do
      nil ->
        {:error, :data_not_found}

      data ->
        @repo.delete(data)
    end
  end

  def delete(_invalid_json) do
    {:error, :json_format_invalid}
  end
end
