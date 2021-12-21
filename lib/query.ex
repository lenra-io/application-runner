defmodule ApplicationRunner.Query do
  @moduledoc """

  """
  alias ApplicationRunner.{Data, Datastore, Refs}

  @repo Application.compile_env!(:application_runner, :repo)

  def create_table(app_id, %{"name" => name}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_datastore, Datastore.new(app_id, name))
    |> @repo.transaction()
  end

  def insert(app_id, lists) when is_list(lists) do
    return = Enum.map(lists, fn list -> handle_insert(app_id, list) end)
    return = Enum.map(return, fn data -> handle_return(data) end)
    {:ok, return}
  end

  def insert(app_id, req) do
    handle_insert(app_id, req)
  end

  def insert(_something) do
    {:error, :json_format_error}
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

  defp handle_refs(datastore_id, data, refBy, refTo) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_data, Data.new(datastore_id, data))
    |> Ecto.Multi.run(:inserted_ref, fn _, %{inserted_data: %Data{} = data} ->
      cond do
        refBy != nil ->
          handle_refBy(refBy, data)

        refTo != nil ->
          handle_refTo(refTo, data)

        true ->
          {:error, :json_ref_format_error}
      end
    end)
    |> @repo.transaction()
  end

  defp handle_refBy(refBy, data) do
    res =
      Enum.map(refBy, fn by ->
        with %Data{} = ref <- @repo.get(Data, by) do
          {:ok, ref} = @repo.insert(Refs.new(ref.id, data.id))
          ref
        else
          _ -> {:error, :ref_not_found}
        end
      end)

    {:ok, res}
  end

  defp handle_refTo(refTo, data) do
    res =
      Enum.map(refTo, fn to ->
        with %Data{} = ref <- @repo.get(Data, to) do
          {:ok, ref} = @repo.insert(Refs.new(data.id, ref.id))
          ref
        else
          _ -> {:error, :ref_not_found}
        end
      end)

    {:ok, res}
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

    {:ok, %{inserted_ref: [[ref] | _tail]}} = result
    {:ok, %{inserted_ref: ref}}
  end

  def handle_insert(_action, _req) do
    {:error, :json_format_error}
  end

  def update(%{"id" => id, "data" => changes}) do
    with %Data{} = data <- @repo.get(Data, id) do
      data
      |> Ecto.Changeset.change(data: changes)
      |> @repo.update()
    else
      _ -> {:error, :data_not_found}
    end
  end

  def update(_) do
    {:error, :json_format_error}
  end

  defp handle_del(list) when is_list(list) do
    Enum.map(list, fn ref -> @repo.delete(ref) end)
  end

  defp handle_del(_) do
    []
  end

  def delete(%{"id" => id}) do
    with %Data{} = data <- @repo.get(Data, id) do
      data
      |> @repo.preload([:referencers, :referenceds])

      handle_del(data.referencers)
      handle_del(data.referenceds)
      @repo.delete(data)
    else
      _ -> {:error, :data_not_found}
    end
  end

  def delete(%{"refBy" => refBys, "refTo" => refTos}) do
    refBys = Enum.map(refBys, fn by -> @repo.get_by(Refs, referencer_id: by) end)
    refTos = Enum.map(refTos, fn to -> @repo.get_by(Refs, referenced_id: to) end)
    to_delete = Enum.uniq(refBys ++ refTos)
    IO.puts(inspect(to_delete))
    handle_del(to_delete)
  end

  def delete(_) do
    {:error, :json_format_error}
  end
end
