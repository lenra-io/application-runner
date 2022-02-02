defmodule ApplicationRunner.Query do
  @moduledoc """
    'ApplicationRunner.Query' transform query in JSON format to an ecto query
  """
  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.{Data, Datastore, DataRaferences}

  @repo Application.compile_env!(:application_runner, :repo)

  # Get all Data from a table
  def get(app_id, %{"table" => table}) do
    case @repo.get_by(Datastore, name: table, environment_id: app_id) do
      nil ->
        {:error, :datastore_not_found}

      %Datastore{} = datastore ->
        case @repo.all(from(d in Data, where: d.datastore_id == ^datastore.id, select: d)) do
          nil -> {:error, :data_not_found}
          data when is_list(data) -> data
        end
    end
  end

  # Get list of data by their id in a table
  def get(%{"table" => table, "ids" => ids}) when is_list(ids) do
    case @repo.get_by(Datastore, name: table) do
      nil ->
        {:error, :datastore_not_found}

      %Datastore{} = datastore ->
        Enum.map(ids, fn id ->
          @repo.all(
            from(d in Data, where: d.datastore_id == ^datastore.id and d.id == ^id, select: d)
          )
        end)
    end
  end

  # Get data referenced by ref_by (list of data id) in a table
  def get(%{"table" => table, "refBy" => ref_by}) when is_list(ref_by) do
    case @repo.get_by(Datastore, name: table) do
      nil ->
        {:error, :data_not_found}

      %Datastore{} = datastore ->
        handle_get_ref_by(datastore, ref_by)
    end
  end

  # Get data referencer refs (list of data id) in a table
  def get(%{"table" => table, "refs" => refs}) when is_list(refs) do
    case @repo.get_by(Datastore, name: table) do
      nil ->
        {:error, :data_not_found}

      %Datastore{} = datastore ->
        handle_get_refs(datastore, refs)
    end
  end

  def get(_anything) do
    {:error, :json_format_error}
  end

  defp handle_get_ref_by(datastore, ref_by) do
    Enum.map(ref_by, fn by ->
      case(@repo.get(Data, by)) do
        nil ->
          {:error, :ref_not_found}

        %Data{} ->
          @repo.all(
            from(d in Data,
              join: r in assoc(d, :referenceds),
              where: r.referencer == ^by and d.datastore_id == ^datastore,
              select: d
            )
          )
      end
    end)
  end

  defp handle_get_refs(datastore, refs) do
    Enum.map(refs, fn to ->
      case(@repo.get(Data, to)) do
        nil ->
          {:error, :ref_not_found}

        %Data{} ->
          @repo.all(
            from(d in Data,
              join: r in assoc(d, :referenceds),
              where:
                r.referenced == ^to and d.datastore_id == ^datastore and r.referencer != d.id,
              select: d
            )
          )
      end
    end)
  end

  # Create Table
  def create_table(app_id, %{"name" => name}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_datastore, Datastore.new(app_id, name))
    |> @repo.transaction()
  end

  def create_table(_app_id, _anything) do
    {:error, :json_format_error}
  end

  # Insert data in a Table
  def insert(app_id, lists) when is_list(lists) do
    return = Enum.map(lists, fn list -> handle_insert(app_id, list) end)
    return = Enum.map(return, fn data -> handle_return(data) end)
    {:ok, %{inserted_data: return}}
  end

  def insert(app_id, req) do
    handle_insert(app_id, req)
  end

  def insert(_something) do
    {:error, :json_format_error}
  end

  # Normalize function returns
  defp handle_return({:ok, %{inserted_data: result}}) do
    result
  end

  defp handle_return({:ok, %{inserted_ref: result}}) do
    result
  end

  defp handle_references(datastore_id, data, ref_by, refs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_data, Data.new(datastore_id, data))
    |> Ecto.Multi.run(:inserted_ref, fn _, %{inserted_data: %Data{} = data} ->
      cond do
        ref_by != nil ->
          handle_ref_by(ref_by, data)

        refs != nil ->
          handle_refs(refs, data)

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
           {:ok, ref} = @repo.insert(DataRaferences.new(ref.id, data.id))
           ref
       end
     end)}
  end

  defp handle_refs(refs, data) do
    {:ok,
     Enum.map(refs, fn to ->
       case @repo.get(Data, to) do
         nil ->
           {:error, :ref_not_found}

         ref ->
           {:ok, ref} = @repo.insert(DataRaferences.new(data.id, ref.id))
           ref
       end
     end)}
  end

  def handle_insert(app_id, %{"table" => table, "data" => data, "refBy" => ref_by}) do
    case @repo.get_by(Datastore, name: table, environment_id: app_id) do
      nil -> {:error, :datastore_not_found}
      datastore -> handle_references(datastore.id, data, ref_by, nil)
    end
  end

  def handle_insert(app_id, %{"table" => table, "data" => data, "refs" => refs}) do
    case @repo.get_by(Datastore, name: table, environment_id: app_id) do
      nil -> {:error, :datastore_not_found}
      datastore -> handle_references(datastore.id, data, nil, refs)
    end
  end

  def handle_insert(app_id, %{"table" => table, "data" => data}) do
    case @repo.get_by(Datastore, name: table, environment_id: app_id) do
      nil ->
        {:error, :datastore_not_found}

      datastore ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:inserted_data, Data.new(datastore.id, data))
        |> @repo.transaction()
    end
  end

  def handle_insert(_id, %{"refBy" => ref_by, "refs" => refs}) do
    {:ok, %{inserted_ref: [[ref] | _tail]}} =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:inserted_ref, fn _, _ ->
        {:ok,
         Enum.map(ref_by, fn by ->
           Enum.map(refs, fn to ->
             {:ok, ref} = @repo.insert(DataRaferences.new(by, to))
             ref
           end)
         end)}
      end)
      |> @repo.transaction()

    {:ok, %{inserted_ref: ref}}
  end

  def handle_insert(_action, _req) do
    {:error, :json_format_error}
  end

  # Update data
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

  # Delete data
  def delete(%{"id" => id}) do
    case @repo.get(Data, id) do
      nil ->
        {:error, :data_not_found}

      data ->
        data =
          data
          |> @repo.preload([:refs, :refBy])

        Ecto.Multi.new()
        |> Ecto.Multi.run(:del_by, fn _, _ ->
          {:ok, delete(%{"refBy" => data.refBy, "refs" => [data]})}
        end)
        |> Ecto.Multi.run(:del_to, fn _, _ ->
          {:ok, delete(%{"refBy" => [data], "refs" => data.refs})}
        end)
        |> Ecto.Multi.run(:del_refs, fn _,
                                        %{
                                          del_by: {:ok, del_by},
                                          del_to: {:ok, del_refs}
                                        } ->
          to_delete = Enum.reduce(del_by, del_refs, &[&1 | &2])
          to_delete = Enum.uniq(to_delete)
          {:ok, handle_del(to_delete)}
        end)
        |> Ecto.Multi.delete(:deleted_data, data)
        |> @repo.transaction()
    end
  end

  def delete(%{"refBy" => ref_bys, "refs" => refss}) do
    ref_bys =
      Enum.map(ref_bys, fn by ->
        handle_delete_return(
          @repo.all(from(r in DataRaferences, where: r.refs_id == ^by.id, select: r))
        )
      end)

    refss =
      Enum.map(refss, fn to ->
        handle_delete_return(
          @repo.all(from(r in DataRaferences, where: r.refBy_id == ^to.id, select: r))
        )
      end)

    to_delete = Enum.reduce(ref_bys, refss, &[&1 | &2])
    to_delete = Enum.filter(to_delete, &(!is_nil(&1)))

    {:ok, to_delete}
  end

  def delete(_) do
    {:error, :json_format_error}
  end

  def handle_delete_return([res]) do
    res
  end

  def handle_delete_return(res) when is_list(res) do
  end

  defp handle_del(list) when is_list(list) do
    Enum.map(list, fn ref ->
      @repo.delete(ref)
    end)
  end
end
