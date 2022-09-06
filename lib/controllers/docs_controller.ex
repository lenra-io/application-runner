defmodule ApplicationRunner.DocsController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.{Guardian.AppGuardian, MongoStorage}
  alias LenraCommon.Errors.DevError

  require Logger

  def action(conn, _) do
    args = [conn, conn.path_params, conn.body_params]
    apply(__MODULE__, action_name(conn), args)
  end

  defp get_resource!(conn) do
    case AppGuardian.Plug.current_resource(conn) do
      nil -> raise DevError.exception(message: "There is no resource loaded from token.")
      res -> res
    end
  end

  def get(conn, %{"coll" => coll, "docId" => doc_id}, _body_params) do
    with %{environment: env} <- get_resource!(conn),
         {:ok, doc} <-
           MongoStorage.fetch_doc(
             env.id,
             coll,
             doc_id
           ) do
      conn
      |> assign_data(doc)
      |> reply
    end
  end

  def get_all(conn, %{"coll" => coll}, _body_params) do
    with %{environment: env} <- get_resource!(conn),
         {:ok, docs} <- MongoStorage.fetch_all_docs(env.id, coll) do
      conn
      |> assign_data(docs)
      |> reply
    end
  end

  def create(conn, %{"coll" => coll}, doc) do
    with %{environment: env} <- get_resource!(conn),
         :ok <- MongoStorage.create_doc(env.id, coll, doc) do
      reply(conn)
    end
  end

  def update(conn, %{"docId" => doc_id, "coll" => coll}, new_doc) do
    with %{environment: env} <- get_resource!(conn),
         {msec, :ok} <- :timer.tc(MongoStorage, :update_doc, [env.id, coll, doc_id, new_doc]) do
      Logger.warn(msec)
      reply(conn)
    end
  end

  def delete(conn, %{"docId" => doc_id, "coll" => coll}, _body_params) do
    with %{environment: env} <- get_resource!(conn),
         :ok <- MongoStorage.delete_doc(env.id, coll, doc_id) do
      reply(conn)
    end

    reply(conn)
  end

  def filter(conn, %{"coll" => coll}, filter) do
    with %{environment: env} <- AppGuardian.Plug.current_resource(conn),
         {:ok, docs} <- MongoStorage.filter_docs(env.id, coll, filter) do
      conn
      |> assign_data(docs)
      |> reply
    end

    reply(conn)
  end
end
