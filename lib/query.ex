defmodule ApplicationRunner.Query do
  @moduledoc """
    'ApplicationRunner.Query' transform query in JSON format to an ecto query
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

  defp handle_refs(datastore_id, data, ref_by, ref_to) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_data, Data.new(datastore_id, data))
    |> Ecto.Multi.run(:inserted_ref, fn _, %{inserted_data: %Data{} = data} ->
      cond do
        ref_by != nil ->
          handle_ref_by(ref_by, data)

        ref_to != nil ->
          handle_ref_to(ref_to, data)

        true ->
          {:error, :json_ref_format_error}
      end
    end)
    |> @repo.transaction()
  end

  defp handle_ref_by(ref_by, data) do
    {:ok,
     Enum.map(ref_by, fn by ->
       case @repo.get(Data, by) do
         nil ->
           {:error, :ref_not_found}

         ref ->
           {:ok, ref} = @repo.insert(Refs.new(ref.id, data.id))
           ref
       end
     end)}
  end

  defp handle_ref_to(ref_to, data) do
    {:ok,
     Enum.map(ref_to, fn to ->
       case @repo.get(Data, to) do
         nil ->
           {:error, :ref_not_found}

         ref ->
           {:ok, ref} = @repo.insert(Refs.new(data.id, ref.id))
           ref
       end
     end)}
  end

  def handle_insert(app_id, %{"table" => table, "data" => data, "refBy" => ref_by}) do
    case @repo.get_by(Datastore, name: table, application_id: app_id) do
      nil -> {:error, :datastore_not_found}
      datastore -> handle_refs(datastore.id, data, ref_by, nil)
    end
  end

  def handle_insert(app_id, %{"table" => table, "data" => data, "refTo" => ref_to}) do
    case @repo.get_by(Datastore, name: table, application_id: app_id) do
      nil -> {:error, :datastore_not_found}
      datastore -> handle_refs(datastore.id, data, nil, ref_to)
    end
  end

  def handle_insert(app_id, %{"table" => table, "data" => data}) do
    case @repo.get_by(Datastore, name: table, application_id: app_id) do
      nil ->
        {:error, :datastore_not_found}

      datastore ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:inserted_data, Data.new(datastore.id, data))
        |> @repo.transaction()
    end
  end

  def handle_insert(_id, %{"refBy" => ref_by, "refTo" => ref_to}) do
    {:ok, %{inserted_ref: [[ref] | _tail]}} =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:inserted_ref, fn _, _ ->
        {:ok,
         Enum.map(ref_by, fn by ->
           Enum.map(ref_to, fn to -> @repo.insert(Refs.new(by, to)) end)
         end)}
      end)
      |> @repo.transaction()

    {:ok, %{inserted_ref: ref}}
  end

  def handle_insert(_action, _req) do
    {:error, :json_format_error}
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
    case @repo.get(Data, id) do
      nil ->
        {:error, :data_not_found}

      data ->
        data
        |> @repo.preload([:referencers, :referenceds])

        handle_del(data.referencers)
        handle_del(data.referenceds)
        @repo.delete(data)
    end
  end

  def delete(%{"refBy" => ref_bys, "refTo" => ref_tos}) do
    ref_bys = Enum.map(ref_bys, fn by -> @repo.get_by(Refs, referencer_id: by) end)
    ref_tos = Enum.map(ref_tos, fn to -> @repo.get_by(Refs, referenced_id: to) end)
    to_delete = Enum.uniq(ref_bys ++ ref_tos)
    IO.puts(inspect(to_delete))
    handle_del(to_delete)
  end

  def delete(_) do
    {:error, :json_format_error}
  end
end
