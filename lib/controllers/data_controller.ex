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

  def create(conn, params) do
    params = reformat_params_with_underscore(params, ["_datastore", "_id"])

    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{inserted_data: data}} <-
           JsonStorage.create_data(session_assigns.environment.id, params) do
      conn
      |> assign_data(:inserted_data, data)
      |> reply
    end
  end

  def update(conn, params) do
    params = reformat_params_with_underscore(params, ["_datastore", "_id"])

    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{updated_data: data}} <-
           JsonStorage.update_data(session_assigns.environment.id, params) do
      conn
      |> assign_data(:updated_data, data)
      |> reply
    end
  end

  def delete(conn, params) do
    params = reformat_params_with_underscore(params, ["_datastore", "_id"])

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

  defp reformat_params_with_underscore(params, key_list) do
    Enum.reduce(key_list, params, &reformat_param_with_underscore/2)
  end

  defp reformat_param_with_underscore("_" <> key = u_key, params) do
    value = Map.get(params, key)

    params
    |> Map.put(u_key, value)
    |> Map.delete(key)
  end
end
