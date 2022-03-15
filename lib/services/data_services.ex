defmodule ApplicationRunner.DataServices do
  @moduledoc """
    The service that manages actions on data.
  """

  alias ApplicationRunner.{Data, Datastore, DataReferences}

  def create(environment_id, op), do: Ecto.Multi.new() |> create(environment_id, op)

  def create(multi, environment_id, %{
        "datastore" => datastore,
        "data" => data,
        "refs" => refs,
        "refBy" => refBy
      })
      when is_list(refs) and is_list(refBy) do
    multi
    |> create(environment_id, %{"datastore" => datastore, "data" => data})
    |> handle_refs(refs)
    |> handle_refBy(refBy)
  end

  def create(multi, environment_id, %{"datastore" => datastore, "data" => data, "refs" => refs})
      when is_list(refs) do
    multi
    |> create(environment_id, %{"datastore" => datastore, "data" => data})
    |> handle_refs(refs)
  end

  def create(multi, environment_id, %{"datastore" => datastore, "data" => data, "refBy" => refBy})
      when is_list(refBy) do
    multi
    |> create(environment_id, %{"datastore" => datastore, "data" => data})
    |> handle_refBy(refBy)
  end

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

  defp handle_refs(multi, refs) do
    Enum.reduce(refs, multi, fn ref, multi ->
      multi
      |> Ecto.Multi.run(String.to_atom("inserted_refs_#{ref}"), fn repo,
                                                                   %{
                                                                     inserted_data: %Data{} = data
                                                                   } ->
        repo.insert(DataReferences.new(%{refs_id: ref, refBy_id: data.id}))
      end)
    end)
  end

  defp handle_refBy(multi, refBy) do
    Enum.reduce(refBy, multi, fn ref, multi ->
      multi
      |> Ecto.Multi.run(String.to_atom("inserted_refBy_#{ref}"), fn repo,
                                                                    %{
                                                                      inserted_data:
                                                                        %Data{} = data
                                                                    } ->
        repo.insert(DataReferences.new(%{refs_id: data.id, refBy_id: ref}))
      end)
    end)
  end

  def update(data_id, op), do: Ecto.Multi.new() |> update(data_id, op)

  def update(multi, data_id, %{"data" => changes}) do
    multi
    |> Ecto.Multi.run(:data, fn repo, _params ->
      case repo.get(Data, data_id) do
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

  def update(multi, _data_id, _invalid_json) do
    multi
    |> Ecto.Multi.run(:data, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end

  def delete(op), do: Ecto.Multi.new() |> delete(op)

  def delete(multi, data_id) do
    multi
    |> Ecto.Multi.run(:data, fn repo, _ ->
      case repo.get(Data, data_id) do
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
end
