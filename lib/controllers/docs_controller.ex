defmodule ApplicationRunner.DocsController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Environment.MongoInstance
  alias ApplicationRunner.{Guardian.AppGuardian, MongoStorage}
  alias LenraCommon.Errors.DevError
  alias QueryParser.Parser

  require Logger

  def action(conn, _) do
    with resources <- get_resource!(conn) do
      mongo_user_id = get_mongo_user_id(resources)
      args = [conn, conn.path_params, conn.body_params, resources, %{"me" => mongo_user_id}]

      Logger.debug(
        "#{__MODULE__} handle #{inspect(conn.method)} on #{inspect(conn.request_path)} with path_params #{inspect(conn.path_params)} and body_params #{inspect(conn.body_params)}"
      )

      apply(__MODULE__, action_name(conn), args)
    end
  end

  defp get_mongo_user_id(%{mongo_user_link: mongo_user_link}) do
    mongo_user_link.mongo_user_id
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
           MongoInstance.run_mongo_task(
             env.id,
             MongoStorage,
             :fetch_doc,
             [env.id, coll, doc_id]
           ) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(doc)}"
      )

      reply(conn, doc)
    end
  end

  def get_all(conn, %{"coll" => coll}, _body_params, %{environment: env}, _replace_params) do
    with {:ok, docs} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :fetch_all_docs, [env.id, coll]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(docs)}"
      )

      reply(conn, docs)
    end
  end

  def create(conn, %{"coll" => coll}, doc, %{environment: env}, replace_params) do
    with filtered_doc <- Map.delete(doc, "_id"),
         {:ok, docs} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :create_doc, [
             env.id,
             coll,
             Parser.replace_params(filtered_doc, replace_params)
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(docs)}"
      )

      reply(conn, docs)
    end
  end

  def update(
        conn,
        %{"docId" => doc_id, "coll" => coll},
        new_doc,
        %{environment: env},
        replace_params
      ) do
    with {:ok, docs} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :update_doc, [
             env.id,
             coll,
             doc_id,
             Parser.replace_params(new_doc, replace_params)
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(docs)}"
      )

      reply(conn, docs)
    end
  end

  def delete(
        conn,
        %{"docId" => doc_id, "coll" => coll},
        _body_params,
        %{environment: env},
        _replace_params
      ) do
    with :ok <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :delete_doc, [env.id, coll, doc_id]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with status :ok"
      )

      reply(conn)
    end
  end

  def find(conn, %{"coll" => coll}, filter, %{environment: env}, %{
        "query" => query,
        "projection" => projection
      }) do
    with {:ok, docs} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :filter_docs, [
             env.id,
             coll,
             Parser.replace_params(filter, query),
             %{projection: projection}
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(docs)}"
      )

      reply(conn, docs)
    end
  end

  def find(conn, %{"coll" => coll}, filter, %{environment: env}, replace_params) do
    Logger.warning(
      "This form of query is depracted prefer use: {query: <yout query>, projection: {projection}}, more info at: https://www.mongodb.com/docs/manual/reference/method/db.collection.find/#mongodb-method-db.collection.find"
    )

    with {:ok, docs} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :filter_docs, [
             env.id,
             coll,
             Parser.replace_params(filter, replace_params)
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(docs)}"
      )

      reply(conn, docs)
    end
  end

  ###############
  # Transaction #
  ###############

  def transaction(conn, _params, _body_params, %{environment: env}, _replace_params) do
    with {:ok, session_uuid} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :start_transaction, [env.id]) do
      reply(conn, session_uuid)
    end
  end

  def commit_transaction(
        conn,
        %{"session_id" => session_id},
        _body_params,
        %{environment: env},
        _replace_params
      ) do
    with :ok <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :commit_transaction, [
             session_id,
             env.id
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with status :ok"
      )

      reply(conn)
    end
  end

  def abort_transaction(
        conn,
        %{"session_id" => session_id},
        _body_params,
        %{environment: env},
        _replace_params
      ) do
    with :ok <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :revert_transaction, [
             session_id,
             env.id
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with status :ok"
      )

      reply(conn)
    end
  end

  def create_transaction(
        conn,
        %{"coll" => coll, "session_id" => session_id},
        doc,
        %{environment: env},
        replace_params
      ) do
    with filtered_doc <- Map.delete(doc, "_id"),
         {:ok, docs} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :create_doc, [
             env.id,
             coll,
             Parser.replace_params(filtered_doc, replace_params),
             session_id
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(docs)}"
      )

      reply(conn, docs)
    end
  end

  def update_transaction(
        conn,
        %{"coll" => coll, "session_id" => session_id, "docId" => doc_id},
        new_doc,
        %{environment: env},
        replace_params
      ) do
    with {:ok, docs} <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :update_doc, [
             env.id,
             coll,
             doc_id,
             Parser.replace_params(new_doc, replace_params),
             session_id
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with res #{inspect(docs)}"
      )

      reply(conn, docs)
    end
  end

  def delete_transaction(
        conn,
        %{"coll" => coll, "docId" => doc_id, "session_id" => session_id},
        _body_params,
        %{environment: env},
        _replace_params
      ) do
    with :ok <-
           MongoInstance.run_mongo_task(env.id, MongoStorage, :delete_doc, [
             env.id,
             coll,
             doc_id,
             session_id
           ]) do
      Logger.debug(
        "#{__MODULE__} respond to #{inspect(conn.method)} on #{inspect(conn.request_path)} with status :ok"
      )

      reply(conn)
    end
  end
end
