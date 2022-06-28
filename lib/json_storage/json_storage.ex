defmodule ApplicationRunner.JsonStorage do
  @moduledoc """
    ApplicationRunner.JsonStorage handle all data logic.
    We can find delegate function to associate Services.
  """

  alias ApplicationRunner.JsonStorage.Services

  ########
  # DATA #
  ########

  defdelegate create_data(environment_id, params), to: Services.Data, as: :create

  defdelegate create_data(multi, environment_id, params), to: Services.Data, as: :create

  defdelegate create_data_multi(multi, environment_id, params), to: Services.Data, as: :create

  defdelegate exec_query(query, env_id, user_id), to: Services.Data, as: :exec_query

  defdelegate parse_and_exec_query(query, env_id, user_id),
    to: Services.Data,
    as: :parse_and_exec_query

  defdelegate get_data(env_id, ds_name, data_id), to: Services.Data, as: :get

  defdelegate get_all_data(query, env_id), to: Services.Data, as: :get_all

  defdelegate get_me(env_id, user_id), to: Services.Data, as: :get_me

  defdelegate update_data(params), to: Services.Data, as: :update

  defdelegate update_data(multi, params), to: Services.Data, as: :update

  defdelegate delete_data(params), to: Services.Data, as: :delete

  defdelegate delete_data(multi, data_id), to: Services.Data, as: :delete

  #############
  # DATASTORE #
  #############

  defdelegate create_datastore(environment_id, params), to: Services.Datastore, as: :create

  defdelegate create_datastore(multi, environment_id, params), to: Services.Datastore, as: :create

  defdelegate update_datastore(datastore_id, params), to: Services.Datastore, as: :update

  defdelegate update_datastore(multi, datastore_id, params), to: Services.Datastore, as: :update

  defdelegate delete_datastore(datastore_id), to: Services.Datastore, as: :delete

  defdelegate delete_datastore(multi, datastore_id), to: Services.Datastore, as: :delete

  #############
  # USERDATA #
  #############

  defdelegate create_user_data(params), to: Services.UserData, as: :create

  defdelegate create_user_data(multi, params), to: Services.UserData, as: :create

  defdelegate create_user_data_with_data(session_state),
    to: Services.UserData,
    as: :create_with_data

  defdelegate has_user_data?(session_state), to: Services.UserData, as: :has_user_data?

  defdelegate current_user_data_query(env_id, user_id),
    to: Services.UserData,
    as: :current_user_data_query

  ##################
  # DATA REFERENCE #
  ##################

  defdelegate create_reference(params), to: Services.DataReferences, as: :create

  defdelegate create_reference(multi, params), to: Services.DataReferences, as: :create

  defdelegate delete_reference(params),
    to: Services.DataReferences,
    as: :delete

  defdelegate delete_reference(multi, params), to: Services.DataReferences, as: :delete

  ##############
  # QUERY VIEW #
  ##############

  defdelegate get_one(env_id, datastore_name, data_id), to: Services.DataQueryView, as: :get_one

  defdelegate get_all(env_id, datastore_name), to: Services.DataQueryView, as: :get_all
end
