defmodule ApplicationRunner.Query do
  @moduledoc """

  """
  alias ApplicationRunner.{Data, Datastore, Refs}

  @repo Application.compile_env!(:application_runner, :repo)
  # @application Application.compile_env!(:application_runner, :lenra_application_schema)

  def insert(%{"app_id" => app_id, "query" => lists}) when is_list(lists) do
    return = Enum.map(lists, fn list -> handle_insert(app_id, list) end)
    return = Enum.map(return, fn data -> handle_return(data) end)
    {:ok, return}
  end

  defp handle_return({:ok, %{inserted_data: result}}) do
    result
  end

  defp handle_return({:ok, %{inserted_ref: result}}) do
    result
  end

  defp handle_return({:ok, %{inserted_datastore: result}}) do
    result
  end

  def insert(%{"app_id" => app_id, "query" => req}) do
    handle_insert(app_id, req)
  end

  defp handle_refs(datastore_id, data, refBy, refTo) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_data, Data.new(datastore_id, data))
    |> Ecto.Multi.run(:inserted_ref, fn _, %{inserted_data: %Data{} = data} ->
      case refBy != nil do
        true ->
          inserted_refs = Enum.map(refBy, fn by -> @repo.insert(Refs.new(by, data.id)) end)
          {:ok, inserted_refs}

        false ->
          case refTo != nil do
            true ->
              inserted_refs = Enum.map(refTo, fn to -> @repo.insert(Refs.new(data.id, to)) end)
              {:ok, inserted_refs}

            false ->
              {:error, :json_ref_format_error}
          end
      end
    end)
    |> @repo.transaction()
  end

  def handle_insert(app_id, %{"name" => name}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_datastore, Datastore.new(app_id, name))
    |> @repo.transaction()
  end

  def handle_insert(app_id, %{"table" => table, "data" => data, "refBy" => refBy}) do
    with %Datastore{} = datastore <-
           @repo.get_by(Datastore, name: table, application_id: app_id) do
      handle_refs(datastore.id, data, refBy, nil)
    else
      _ -> {:error, :datastore_not_found}
    end
  end

  def handle_insert(app_id, %{"table" => table, "data" => data, "refTo" => refTo}) do
    with %Datastore{} = datastore <-
           @repo.get_by(Datastore, name: table, application_id: app_id) do
      handle_refs(datastore.id, data, nil, refTo)
    else
      _ -> {:error, :datastore_not_found}
    end
  end

  def handle_insert(app_id, %{"table" => table, "data" => data}) do
    with %Datastore{} = datastore <-
           @repo.get_by(Datastore, name: table, application_id: app_id) do
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:inserted_data, Data.new(datastore.id, data))
      |> @repo.transaction()
    else
      _ -> {:error, :datastore_not_found}
    end
  end

  def handle_insert(_id, %{"refBy" => refBy, "refTo" => refTo}) do
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:inserted_ref, fn _, _ ->
        refs =
          Enum.map(refBy, fn by ->
            Enum.map(refTo, fn to -> @repo.insert(Refs.new(by, to)) end)
          end)

        {:ok, refs}
      end)
      |> @repo.transaction()

    {:ok, %{inserted_ref: [[ok: ref] | _tail]}} = result
    {:ok, %{inserted_ref: ref}}
  end

  def handle_insert(_action, _req) do
    {:error, :json_format_error}
  end

  def update(%{"app_id" => _app_id, "query" => %{"id" => id, "data" => changes}}) do
    @repo.get(Data, id)
    |> Ecto.Changeset.change(changes)
    |> @repo.update()
  end

  def update(_) do
    {:error, :json_format_error}
  end

  defp handle_del([] = list) do
    Enum.map(list, fn ref -> @repo.delete(ref) end)
  end

  defp handle_del(_) do
  end

  def delete(%{"app_id" => _app_id, "query" => %{"id" => id}}) do
    with %Data{} = data <- @repo.get(Data, id) do
      data
      |> @repo.preload([:referencer, :referenced])

      IO.puts(inspect(data))
      handle_del(data.referencer)
      handle_del(data.referenced)
      @repo.delete(data)
    else
      _ -> {:error, :data_not_found}
    end
  end

  def delete(_) do
    {:error, :json_format_error}
  end
end
