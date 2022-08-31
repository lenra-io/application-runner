defmodule ApplicationRunner.MongoStorage do
  @moduledoc """
    ApplicationRunner.JsonStorage handles all data logic.
    We can find delegate function to associate Services.
  """
  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.MongoStorage.MongoUserLink
  @repo Application.compile_env(:application_runner, :repo)

  # alias ApplicationRunner.JsonStorage.Services

  def has_user_link?(env_id, user_id) do
    query =
      from(u in MongoUserLink,
        where: u.user_id == ^user_id and u.environment_id == ^env_id
      )

    @repo.exists?(query)
  end

  def create_user_link(%{environment_id: _, user_id: _} = params) do
    MongoUserLink.new(params)
    |> @repo.insert()
  end

  ########
  # DATA #
  ########

  # defdelegate create_data(environment_id, params), to: Services.Data, as: :create

  # defdelegate parse_and_exec_query(env_id, coll, query),
  #   to: Services.Data,
  #   as: :parse_and_exec_query

  # defdelegate get_data(env_id, coll, data_id), to: Services.Data, as: :get

  # defdelegate get_all_data(env_id, coll), to: Services.Data, as: :get_all

  # defdelegate get_current_user_data(env_id, user_id),
  #   to: Services.Data,
  #   as: :get_current_user_data

  # defdelegate update_data(environment_id, params), to: Services.Data, as: :update

  # defdelegate delete_data(environment_id, params), to: Services.Data, as: :delete

  #############
  # DATASTORE #
  #############

  # defdelegate create_datastore(environment_id, params), to: Services.Datastore, as: :create

  # defdelegate update_datastore(datastore_id, params), to: Services.Datastore, as: :update

  # defdelegate delete_datastore(datastore_id), to: Services.Datastore, as: :delete

  #############
  # USERDATA #
  #############

  # defdelegate create_user_data(params), to: Services.UserData, as: :create

  # defdelegate create_user_data_with_data(env_id, user_id),
  #   to: Services.UserData,
  #   as: :create_with_data

  # defdelegate has_user_data?(env_id, user_id), to: Services.UserData, as: :has_user_data?

  # defdelegate current_user_data_query(env_id, user_id),
  #   to: Services.UserData,
  #   as: :current_user_data_query

  ##################
  # DATA REFERENCE #
  ##################

  # defdelegate create_reference(params), to: Services.DataReferences, as: :create

  # defdelegate delete_reference(params),
  #   to: Services.DataReferences,
  #   as: :delete

  ##############
  # QUERY VIEW #
  ##############

  # defdelegate get_one(env_id, datastore_name, data_id), to: Services.DataQueryView, as: :get_one

  # defdelegate get_all(env_id, datastore_name), to: Services.DataQueryView, as: :get_all
end
