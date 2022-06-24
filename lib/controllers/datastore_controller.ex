defmodule ApplicationRunner.DatastoreController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.{DatastoreServices, Guardian.AppGuardian.Plug}

  def create(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{inserted_datastore: datastore}} <-
           DatastoreServices.create(session_assigns.environment.id, params) do
      conn
      |> assign_data(:inserted_datastore, datastore)
      |> reply
    end
  end

  def delete(conn, params) do
    with session_assigns <- Plug.current_resource(conn),
         {:ok, %{deleted_datastore: datastore}} <-
           DatastoreServices.delete(params["_datastore"], session_assigns.environment.id) do
      conn
      |> assign_data(:deleted_datastore, datastore)
      |> reply
    end
  end
end
