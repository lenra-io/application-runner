defmodule ApplicationRunner.DataReferenceController do
  use ApplicationRunner, :controller

  # alias ApplicationRunner.JsonStorage

  def create(conn, _params) do
    # with {:ok, inserted_reference: reference} <- JsonStorage.create_reference(params) do
    #   conn
    #   |> assign_data(reference)
    #   |> reply
    # end
    reply(conn)
  end

  def delete(conn, _params) do
    # with {:ok, deleted_reference: reference} <- JsonStorage.delete_reference(params) do
    #   conn
    #   |> assign_data(reference)
    #   |> reply
    # end
    reply(conn)
  end
end
