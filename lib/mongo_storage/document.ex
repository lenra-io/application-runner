defmodule ApplicationRunner.MongoStorage.Document do
  @moduledoc """
    The service that manages actions on data.
  """

  alias ApplicationRunner.Environment.MongoInstance

  def parse_and_exec_query(env_id, coll, query) do
    env_id
    |> MongoInstance.get_full_name()
    |> Mongo.find(coll, query)

    # TODO : Handle error to return a technical/Business error
    # TODO : Add @spec
  end

  ##########
  # get #
  ##########

  def get(env_id, coll, data_id) do
    env_id
    |> MongoInstance.get_full_name()
    |> Mongo.find_one(coll, %{"_id" => data_id})

    # TODO : Handle error to return a technical/Business error
    # TODO : Add @spec
  end

  def get_all(env_id, coll) do
    env_id
    |> MongoInstance.get_full_name()
    |> Mongo.find(coll, %{})

    # TODO : Handle error to return a technical/Business error
    # TODO : Add @spec
  end

  def get_current_user_data(env_id, user_id) do
    # TODO : Find a new way to handle the user_data (?)
    {:ok, %{}}
  end

  defp get_user_data_id(env_id, user_id) do
    # TODO : Find a new way to handle user_data_id (?)
    42
  end

  ##########
  # CREATE #
  ##########
  # def create(environment_id, params) do
  #   Ecto.Multi.new()
  #   |> create(environment_id, params)
  # end

  # def create(multi, environment_id, params) do
  #   {data, metadata} = process_params(params)

  #   multi
  #   |> get_datastore(environment_id, metadata)
  #   |> insert_data(data)
  #   |> handle_refs(metadata)
  #   |> handle_ref_by(metadata)
  #   |> @repo.transaction()
  # end

  # def create_multi(multi, environment_id, params) do
  #   {data, metadata} = process_params(params)

  #   multi
  #   |> get_datastore(environment_id, metadata)
  #   |> insert_data(data)
  #   |> handle_refs(metadata)
  #   |> handle_ref_by(metadata)
  # end

  # defp get_datastore(multi, environment_id, %{"_datastore" => datastore})
  #      when is_bitstring(datastore) do
  #   Ecto.Multi.run(multi, :datastore, fn repo, _params ->
  #     case repo.get_by(Datastore, name: datastore, environment_id: environment_id) do
  #       nil ->
  #         TechnicalError.datastore_not_found_tuple()

  #       datastore ->
  #         {:ok, datastore}
  #     end
  #   end)
  # end

  # defp get_datastore(multi, _environment_id, _metadata) do
  #   Ecto.Multi.error(multi, :data, BusinessError.json_format_invalid())
  # end

  # defp insert_data(multi, data) do
  #   Ecto.Multi.insert(multi, :inserted_data, fn %{datastore: %Datastore{} = datastore} ->
  #     Data.new(datastore.id, data)
  #   end)
  # end

  # defp handle_refs(multi, %{"_refs" => refs}) when is_list(refs) do
  #   Enum.reduce(refs, multi, fn ref, multi ->
  #     multi
  #     |> Ecto.Multi.run(
  #       "inserted_refs_#{ref}",
  #       fn repo,
  #          %{
  #            inserted_data: %Data{} = data
  #          } ->
  #         repo.insert(DataReferences.new(%{refs_id: ref, ref_by_id: data.id}))
  #       end
  #     )
  #   end)
  # end

  # defp handle_refs(multi, %{"_refs" => _refs}) do
  #   Ecto.Multi.error(multi, :data, BusinessError.json_format_invalid())
  # end

  # defp handle_refs(multi, _metadata) do
  #   multi
  # end

  # defp handle_ref_by(multi, %{"_refBy" => ref_by}) when is_list(ref_by) do
  #   Enum.reduce(ref_by, multi, fn ref, multi ->
  #     multi
  #     |> Ecto.Multi.run(
  #       "inserted_refBy_#{ref}",
  #       fn repo,
  #          %{
  #            inserted_data: %Data{} = data
  #          } ->
  #         repo.insert(DataReferences.new(%{refs_id: data.id, ref_by_id: ref}))
  #       end
  #     )
  #   end)
  # end

  # defp handle_ref_by(multi, %{"_refBy" => _ref_by}) do
  #   Ecto.Multi.error(multi, :data, BusinessError.json_format_invalid())
  # end

  # defp handle_ref_by(multi, _metadata) do
  #   multi
  # end

  ##########
  # UPDATE #
  ##########
  # def update(env_id, params), do: Ecto.Multi.new() |> update(env_id, params)

  # def update(multi, env_id, params) do
  #   {new_data, %{"_id" => data_id} = metadata} = process_params(params)

  #   multi
  #   |> get_old_data(env_id, data_id)
  #   |> update_refs(metadata)
  #   |> update_ref_by(metadata)
  #   |> update_data(new_data)
  #   |> @repo.transaction()
  # end

  # defp update_data(multi, new_data) do
  #   Ecto.Multi.update(multi, :updated_data, fn %{data: %Data{} = data} ->
  #     Data.update(data, %{"data" => new_data})
  #   end)
  # end

  # defp get_old_data(multi, env_id, data_id) do
  #   Ecto.Multi.run(multi, :data, fn repo, _previous ->
  #     data =
  #       from(d in Data,
  #         join: ds in Datastore,
  #         on: d.datastore_id == ds.id,
  #         where: ds.environment_id == ^env_id and d.id == ^data_id,
  #         select: d
  #       )
  #       |> repo.one()

  #     case data do
  #       nil ->
  #         TechnicalError.data_not_found_tuple()

  #       data ->
  #         {:ok, data}
  #     end
  #   end)
  # end

  # defp update_refs(multi, %{"_refs" => refs}) when is_list(refs) do
  #   handle_update_reference(multi, refs, :refs)
  # end

  # defp update_refs(multi, %{"_refs" => _refs}) do
  #   Ecto.Multi.error(multi, :data, BusinessError.json_format_invalid())
  # end

  # defp update_refs(multi, _metadata) do
  #   multi
  # end

  # defp update_ref_by(multi, %{"_refBy" => ref_by}) when is_list(ref_by) do
  #   handle_update_reference(multi, ref_by, :ref_by)
  # end

  # defp update_ref_by(multi, %{"_refBy" => _refs}) do
  #   Ecto.Multi.error(multi, :data, BusinessError.json_format_invalid())
  # end

  # defp update_ref_by(multi, _metadata) do
  #   multi
  # end

  # defp handle_update_reference(multi, references, key) do
  #   multi
  #   |> Ecto.Multi.run(key, fn repo, %{data: %Data{} = data} ->
  #     env_id =
  #       from(ds in Datastore,
  #         join: d in Data,
  #         on: d.datastore_id == ds.id,
  #         where: d.id == ^data.id,
  #         select: ds.environment_id
  #       )
  #       |> repo.one()

  #     data_ref =
  #       from(d in Data,
  #         join: ds in Datastore,
  #         on: d.datastore_id == ds.id,
  #         where: d.id in ^references and ds.environment_id == ^env_id,
  #         select: d
  #       )
  #       |> repo.all()

  #     case length(data_ref) == length(references) do
  #       true ->
  #         data
  #         |> repo.preload(key)
  #         |> Ecto.Changeset.change()
  #         |> Ecto.Changeset.put_assoc(
  #           key,
  #           data_ref
  #         )
  #         |> repo.update()

  #       false ->
  #         TechnicalError.reference_not_found_tuple()
  #     end
  #   end)
  # end

  # def delete(env_id, params), do: Ecto.Multi.new() |> delete(env_id, params)

  # def delete(multi, env_id, data_id) do
  #   multi
  #   |> get_old_data(env_id, data_id)
  #   |> Ecto.Multi.delete(:deleted_data, fn %{data: %Data{} = data} ->
  #     data
  #   end)
  #   |> @repo.transaction()
  # end

  # defp process_params(params) do
  #   Enum.reduce(params, {%{}, %{}}, fn {k, v}, {data, metadata} ->
  #     if String.starts_with?(k, "_") do
  #       {data, Map.put(metadata, k, v)}
  #     else
  #       {Map.put(data, k, v), metadata}
  #     end
  #   end)
  # end
end
