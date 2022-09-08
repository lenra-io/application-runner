defmodule ApplicationRunner.DocsController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.{Guardian.AppGuardian, MongoStorage}
  alias ApplicationRunner.MongoStorage.MongoUserLink
  alias LenraCommon.Errors.DevError
  alias QueryParser.Parser

  require Logger

  def action(conn, _) do
    with resources <- get_resource!(conn) do
      mongo_user_id = get_mongo_user_id(resources)
      args = [conn, conn.path_params, conn.body_params, resources, %{"me" => mongo_user_id}]

      apply(__MODULE__, action_name(conn), args)
    end
  end

  defp get_mongo_user_id(%{environment: env, user: user}) do
    %MongoUserLink{mongo_user_id: mongo_user_id} =
      MongoStorage.get_mongo_user_link!(env.id, user.id)

    mongo_user_id
  end

  defp get_mongo_user_id(_res) do
    nil
  end

  defp get_resource!(conn) do
    case AppGuardian.Plug.current_resource(conn) do
      nil -> raise DevError.exception(message: "There is no resource loaded from token.")
      res -> res
    end
  end

  def get(
        conn,
        %{"coll" => coll, "docId" => doc_id},
        _body_params,
        %{environment: env},
        _replace_params
      ) do
    with {:ok, doc} <-
           MongoStorage.fetch_doc(
             env.id,
             coll,
             doc_id
           ) do
      reply(conn, doc)
    end
  end

  def get_all(conn, %{"coll" => coll}, _body_params, %{environment: env}, _replace_params) do
    with {:ok, docs} <- MongoStorage.fetch_all_docs(env.id, coll) do
      reply(conn, docs)
    end
  end

  def create(conn, %{"coll" => coll}, doc, %{environment: env}, replace_params) do
    with :ok <-
           MongoStorage.create_doc(
             env.id,
             coll,
             Parser.replace_params(doc, replace_params)
           ) do
      reply(conn)
    end
  end

  def update(
        conn,
        %{"docId" => doc_id, "coll" => coll},
        new_doc,
        %{environment: env},
        replace_params
      ) do
    with :ok <-
           MongoStorage.update_doc(
             env.id,
             coll,
             doc_id,
             Parser.replace_params(new_doc, replace_params)
           ) do
      reply(conn)
    end
  end

  def delete(
        conn,
        %{"docId" => doc_id, "coll" => coll},
        _body_params,
        %{environment: env},
        _replace_params
      ) do
    with :ok <- MongoStorage.delete_doc(env.id, coll, doc_id) do
      reply(conn)
    end
  end

  def filter(conn, %{"coll" => coll}, filter, %{environment: env}, replace_params) do
    with {:ok, docs} <-
           MongoStorage.filter_docs(env.id, coll, Parser.replace_params(filter, replace_params)) do
      reply(conn, docs)
    end
  end
end
