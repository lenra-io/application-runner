defmodule ApplicationRunner.DataReferenceController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.JsonStorage

  def create(conn, params) do
    with {:ok, inserted_reference: reference} <- JsonStorage.create_reference(params) do
      conn
      |> assign_data(:inserted_reference, reference)
      |> reply
    end
  end

  def delete(conn, params) do
    with {:ok, deleted_reference: reference} <- JsonStorage.delete_reference(params) do
      conn
      |> assign_data(:deleted_reference, reference)
      |> reply
    end
  end
end
