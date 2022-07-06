defmodule ApplicationRunner.DatastoreController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.{Guardian.AppGuardian.Plug, JsonStorage}

  def create(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{inserted_datastore: datastore}} <-
           JsonStorage.create_datastore(session_assigns.environment.id, params) do
      conn
      |> assign_data(:inserted_datastore, datastore)
      |> reply
    end
  end

  def delete(conn, params) do
    with {:ok, %{deleted_datastore: datastore}} <-
           JsonStorage.delete_datastore(params["datastore"]) do
      conn
      |> assign_data(:deleted_datastore, datastore)
      |> reply
    end
  end
end
