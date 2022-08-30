defmodule ApplicationRunner.DocsController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.{Guardian.AppGuardian.Plug, MongoStorage}
  alias ApplicationRunner.Errors.BusinessError

  def action(conn, _) do
    args = [conn, conn.path_params, conn.body_params]
    apply(__MODULE__, action_name(conn), args)
  end

  def get(conn, %{"coll" => coll, "docId" => doc_id}, _body_params) do
    with %{environment: env} <- Plug.current_resource(conn),
         {:ok, result} <-
           MongoStorage.fetch_doc(
             env.id,
             coll,
             doc_id
           ) do
      conn
      |> assign_data(result.data)
      |> reply
    end
  end

  def get(_conn, _path_params, _body_params) do
    BusinessError.invalid_route_tuple()
  end

  def get_all(conn, %{"coll" => coll}, _body_params) do
    with %{environment: env} <- Plug.current_resource(conn),
         {:ok, docs} <- MongoStorage.fetch_all_docs(env.id, coll) do
      conn
      |> assign_data(docs)
      |> reply
    end
  end

  def get_all(_conn, _path_params, _body_params) do
    BusinessError.invalid_route_tuple()
  end

  def create(conn, %{"coll" => coll}, doc) do
    with %{environment: env} <- Plug.current_resource(conn),
         :ok <- MongoStorage.create_doc(env.id, coll, doc) do
      reply(conn)
    end
  end

  def create(_conn, _path_params, _body_params) do
    BusinessError.invalid_route_tuple()
  end

  def update(conn, %{"docId" => doc_id, "coll" => coll}, new_doc) do
    with %{environment: env} <- Plug.current_resource(conn),
         :ok <- MongoStorage.update_doc(env.id, coll, doc_id, new_doc) do
      reply(conn)
    end
  end

  def update(_conn, _path_params, _body_params) do
    BusinessError.invalid_route_tuple()
  end

  def delete(conn, %{"docId" => doc_id, "coll" => coll}, _body_params) do
    with %{environment: env} <- Plug.current_resource(conn),
         :ok <- MongoStorage.delete_doc(env.id, coll, doc_id) do
      reply(conn)
    end

    reply(conn)
  end

  def delete(_conn, _path_params, _body_params) do
    BusinessError.invalid_route_tuple()
  end

  def filter(conn, %{"coll" => coll}, filter) do
    with %{environment: env} <- Plug.current_resource(conn),
         {:ok, docs} <- MongoStorage.filter_docs(env.id, coll, filter) do
      conn
      |> assign_data(docs)
      |> reply
    end

    reply(conn)
  end

  def filter(_conn, _path_params, _body_params) do
    BusinessError.invalid_route_tuple()
  end
end
