defmodule ApplicationRunner.DataController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.{DataServices, Guardian.AppGuardian.Plug}

  def get(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         result <-
           DataServices.get(session_assigns.environment.id, params["_datastore"], params["_id"]) do
      conn
      |> assign_all(result.data)
      |> reply
    end
  end

  def get_all(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         result <- DataServices.get_all(session_assigns.environment.id, params["_datastore"]) do
      conn
      |> assign_all(Enum.map(result, fn r -> r.data end))
      |> reply
    end
  end

  def get_me(conn, _params) do
    with session_assigns <- Plug.current_resource(conn),
         result <- DataServices.get_me(session_assigns.environment.id, session_assigns.user.id) do
      conn
      |> assign_data(:user_data, result)
      |> reply
    end
  end

  def create(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{inserted_data: data}} <-
           DataServices.create(session_assigns.environment.id, params) do
      conn
      |> assign_data(:inserted_data, data)
      |> reply
    end
  end

  def update(conn, params) do
    with {:ok, %{updated_data: data}} <- DataServices.update(params) do
      conn
      |> assign_data(:updated_data, data)
      |> reply
    end
  end

  def delete(conn, params) do
    with {:ok, %{deleted_data: data}} <- DataServices.delete(params["_id"]) do
      conn
      |> assign_data(:deleted_data, data)
      |> reply
    end
  end

  def query(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         data <-
           DataServices.parse_and_exec_query(
             params,
             session_assigns.environment.id,
             session_assigns.user.id
           ) do
      conn
      |> assign_all(data)
      |> reply
    end
  end
end
