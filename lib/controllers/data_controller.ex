defmodule ApplicationRunner.DataController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.{Guardian.AppGuardian.Plug, JsonStorage}

  def get(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         result <-
           JsonStorage.get_data(
             session_assigns.environment.id,
             params["datastore"],
             params["id"]
           ) do
      conn
      |> assign_all(result.data)
      |> reply
    end
  end

  def get_all(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         result <- JsonStorage.get_all_data(session_assigns.environment.id, params["datastore"]) do
      conn
      |> assign_all(Enum.map(result, fn r -> r.data end))
      |> reply
    end
  end

  def get_current_user_data(conn, _params) do
    with session_assigns <- Plug.current_resource(conn),
         result <-
           JsonStorage.get_current_user_data(
             session_assigns.environment.id,
             session_assigns.user.id
           ) do
      conn
      |> assign_data(:user_data, result)
      |> reply
    end
  end

  def create(conn, _params) do
    params =
      reformat_params_with_underscore(conn.body_params, conn.path_params, ["_datastore", "_id"])

    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{inserted_data: data}} <-
           JsonStorage.create_data(session_assigns.environment.id, params) do
      conn
      |> assign_data(:inserted_data, data)
      |> reply
    end
  end

  def update(conn, _params) do
    params =
      reformat_params_with_underscore(conn.body_params, conn.path_params, ["_datastore", "_id"])

    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{updated_data: data}} <-
           JsonStorage.update_data(session_assigns.environment.id, params) do
      conn
      |> assign_data(:updated_data, data)
      |> reply
    end
  end

  def delete(conn, _params) do
    params =
      reformat_params_with_underscore(conn.body_params, conn.path_params, ["_datastore", "_id"])

    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{deleted_data: data}} <-
           JsonStorage.delete_data(session_assigns.environment.id, params["_id"]) do
      conn
      |> assign_data(:deleted_data, data)
      |> reply
    end
  end

  def query(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         data <-
           JsonStorage.parse_and_exec_query(
             params,
             session_assigns.environment.id,
             session_assigns.user.id
           ) do
      conn
      |> assign_all(data)
      |> reply
    end
  end

  # On the phoenix controller the body and path params (variable in the route) create a "params" object.
  # for most of the "Data" and "Datastore" routes, the params contains two sort of keys.
  # - The "json data" keys that are the data that the dev wants to store
  # - And the "Metadata" keys that are informations for us to create the data (_datastore, _id, _refs, _refBy..)
  # The _datastore and _id metadata are "path params" that should be defined in the route.
  # But we cannot put underscores "_" in the route without a lot of warning everywhere.
  # To avoid these warnings, we set the variable without the "_" in the route and transform them in the
  # Controller with this function.
  #
  # !!! Since "id" is a valid json_data the dev can provide, we must first transform only the path_params
  # to add the underscores. Only then we can merge this transformed params to the body_params.
  defp reformat_params_with_underscore(body_params, path_params, key_list) do
    Enum.reduce(key_list, path_params, &reformat_param_with_underscore/2)
    |> Map.merge(body_params)
  end

  defp reformat_param_with_underscore("_" <> key = u_key, path_params) do
    value = Map.get(path_params, key)

    path_params
    |> Map.put(u_key, value)
    |> Map.delete(key)
  end
end
