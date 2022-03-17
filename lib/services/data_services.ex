defmodule ApplicationRunner.DataServices do
  @moduledoc """
    The service that manages actions on data.
  """

  alias ApplicationRunner.{Data, DataReferences, Datastore}
  import Ecto.Query, only: [from: 2]

  def create(environment_id, op), do: Ecto.Multi.new() |> create(environment_id, op)

  def create(multi, environment_id, %{
        "datastore" => datastore,
        "data" => data,
        "refs" => refs,
        "refBy" => ref_by
      })
      when is_list(refs) and is_list(ref_by) do
    multi
    |> create(environment_id, %{"datastore" => datastore, "data" => data})
    |> handle_refs(refs)
    |> handle_ref_by(ref_by)
  end

  def create(multi, environment_id, %{"datastore" => datastore, "data" => data, "refs" => refs})
      when is_list(refs) do
    multi
    |> create(environment_id, %{"datastore" => datastore, "data" => data})
    |> handle_refs(refs)
  end

  def create(multi, environment_id, %{"datastore" => datastore, "data" => data, "refBy" => ref_by})
      when is_list(ref_by) do
    multi
    |> create(environment_id, %{"datastore" => datastore, "data" => data})
    |> handle_ref_by(ref_by)
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

  defp handle_ref_by(multi, refBy) do
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

  def update(data_id, changes), do: Ecto.Multi.new() |> update(data_id, changes)

  def update(multi, data_id, changes) do
    multi
    |> Ecto.Multi.run(:data, fn repo, _params ->
      case repo.get(Data, data_id) do
        nil ->
          {:error, :data_not_found}

        data ->
          {:ok, data}
      end
    end)
    |> update_refs(changes)
    |> update_ref_by(changes)
    |> Ecto.Multi.update(:updated_data, fn %{data: %Data{} = data} ->
      data
      |> Data.update(changes)
    end)
  end

  defp update_refs(multi, %{"refs" => refs}) do
    data_ref =
      from(d in Data,
        where: d.id in ^refs,
        select: d
      )

    multi
    |> Ecto.Multi.run(:refs, fn repo, %{data: %Data{} = data} ->
      data
      |> repo.preload(:refs)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(
        :refs,
        repo.all(data_ref)
      )
      |> repo.update()
    end)
  end

  defp update_refs(multi, _json), do: multi

  defp update_ref_by(multi, %{"refBy" => ref_by}) do
    data_ref_by =
      from(d in Data,
        where: d.id in ^ref_by,
        select: d
      )

    multi
    |> Ecto.Multi.run(:refBy, fn repo, %{data: %Data{} = data} ->
      data
      |> repo.preload(:refBy)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(
        :refBy,
        repo.all(data_ref_by)
      )
      |> repo.update()
    end)
  end

  defp update_ref_by(multi, _json), do: multi

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
