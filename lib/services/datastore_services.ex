defmodule ApplicationRunner.DatastoreServices do
  @moduledoc """
    The datastore service.
  """

  alias ApplicationRunner.{Datastore}

  @repo Application.compile_env!(:application_runner, :repo)

  def create(environment_id, %{"name" => name}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_datastore, Datastore.new(environment_id, name))
    |> @repo.transaction()
  end

  def create(_app_id, _anything) do
    {:error, :json_format_error}
  end

  def update(environment_id, %{"name" => name, "new_name" => new_name}) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(
      :datastore,
      @repo.get_by(Datastore, name: name, environment_id: environment_id)
    )
    |> Ecto.Multi.run(:inserted_datastore, fn _, %{datastore: %Datastore{} = datastore} ->
      @repo.update(Ecto.Changeset.change(datastore, name: new_name))
    end)
    |> @repo.transaction()
  end

  def update(_app_id, _anything) do
    {:error, :json_format_error}
  end

  def delete(environment_id, %{"name" => name}) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(
      :datastore,
      @repo.get_by(Datastore, name: name, environment_id: environment_id)
    )
    |> Ecto.Multi.run(:inserted_datastore, fn _, %{datastore: %Datastore{} = datastore} ->
      @repo.delete(datastore)
    end)
    |> @repo.transaction()
  end

  def delete(_app_id, _anything) do
    {:error, :json_format_error}
  end
end
