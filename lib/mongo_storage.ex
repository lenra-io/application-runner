defmodule ApplicationRunner.MongoStorage do
  @moduledoc """
    ApplicationRunner.JsonStorage handles all data logic.
    We can find delegate function to associate Services.
  """
  import Ecto.Query, only: [from: 2]

  alias Inspect.PID
  alias ApplicationRunner.Contract
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.MongoStorage.MongoUserLink
  alias LenraCommon.Errors.TechnicalError, as: TechnicalErrorType

  import Ecto.Query

  defp mongo_instance(env_id) do
    Environment.MongoInstance.get_full_name(env_id)
  end

  defp repo do
    Application.get_env(:application_runner, :repo)
  end

  ###############
  # Environment #
  ###############

  @spec get_env!(number()) :: any
  def get_env!(env_id) do
    repo().get!(Contract.Environment, env_id)
  end

  ########
  # User #
  ########

  @spec get_user!(number()) :: any
  def get_user!(user_id) do
    repo().get!(Contract.User, user_id)
  end

  #################
  # MongoUserLink #
  #################

  @spec get_mongo_user_link!(number(), number()) :: any
  def get_mongo_user_link!(env_id, user_id) do
    repo().one!(
      from(mul in MongoUserLink, where: mul.user_id == ^user_id and mul.environment_id == ^env_id)
    )
  end

  @spec has_user_link?(number(), number()) :: any()
  def has_user_link?(env_id, user_id) do
    query =
      from(u in MongoUserLink,
        where: u.user_id == ^user_id and u.environment_id == ^env_id
      )

    repo().exists?(query)
  end

  @spec create_user_link(map()) :: any()
  def create_user_link(%{environment_id: _, user_id: _} = params) do
    MongoUserLink.new(params)
    |> repo().insert()
  end

  ########
  # DATA #
  ########

  @spec create_doc(number(), String.t(), map(), any()) ::
          {:ok, map()} | {:error, TechnicalErrorType.t()}
  def create_doc(env_id, coll, doc, session_uuid \\ nil) do
    decoded_doc = decode_ids(doc)

    env_id
    |> mongo_instance()
    |> handle_create_doc(session_uuid, coll, decoded_doc)
    |> case do
      {:error, err} ->
        TechnicalError.mongo_error_tuple(err)

      {:ok, res} ->
        {:ok, Map.put(doc, "_id", res.inserted_id)}
    end
  end

  defp handle_create_doc(pipe, session_uuid, coll, decoded_doc) do
    if session_uuid != nil do
      pipe
      |> Mongo.insert_one(coll, decoded_doc, session: Swarm.whereis_name(session_uuid))
    else
      pipe
      |> Mongo.insert_one(coll, decoded_doc)
    end
  end

  @spec fetch_doc(number(), String.t(), term()) :: {:ok, map()} | {:error, TechnicalErrorType.t()}
  def fetch_doc(env_id, coll, doc_id) when is_bitstring(doc_id) do
    with {:ok, bson_doc_id} <- decode_object_id(doc_id) do
      fetch_doc(env_id, coll, bson_doc_id)
    end
  end

  def fetch_doc(env_id, coll, bson_doc_id) when is_struct(bson_doc_id, BSON.ObjectId) do
    env_id
    |> mongo_instance()
    |> Mongo.find_one(coll, %{"_id" => bson_doc_id})
    |> case do
      {:error, err} ->
        TechnicalError.mongo_error_tuple(err)

      res ->
        {:ok, res}
    end
  end

  @spec fetch_all_docs(number(), String.t()) ::
          {:ok, list(map())} | {:error, TechnicalErrorType.t()}
  def fetch_all_docs(env_id, coll) do
    env_id
    |> mongo_instance()
    |> Mongo.find(coll, %{})
    |> case do
      {:error, err} ->
        TechnicalError.mongo_error_tuple(err)

      cursor ->
        {:ok, Enum.to_list(cursor)}
    end
  end

  @spec filter_docs(number(), String.t(), map()) ::
          {:ok, list(map())} | {:error, TechnicalErrorType.t()}
  def filter_docs(env_id, coll, filter) do
    clean_filter = decode_ids(filter)

    env_id
    |> mongo_instance()
    |> Mongo.find(coll, clean_filter)
    |> case do
      {:error, err} ->
        TechnicalError.mongo_error_tuple(err)

      cursor ->
        {:ok, Enum.to_list(cursor)}
    end
  end

  @spec update_doc(number(), String.t(), String.t(), map(), any()) ::
          {:ok, map()} | {:error, TechnicalErrorType.t()}
  def update_doc(env_id, coll, doc_id, new_doc, session_uuid \\ nil) do
    with {:ok, bson_doc_id} <- decode_object_id(doc_id),
         decoded_doc <- decode_ids(new_doc),
         {_value, filtered_doc} <- Map.pop(decoded_doc, "_id") do
      env_id
      |> mongo_instance()
      |> handle_update_doc(session_uuid, coll, bson_doc_id, filtered_doc)
      |> case do
        {:error, err} ->
          TechnicalError.mongo_error_tuple(err)

        _res ->
          {:ok, Map.put(decoded_doc, "_id", bson_doc_id)}
      end
    end
  end

  defp handle_update_doc(pipe, session_uuid, coll, bson_doc_id, filtered_doc) do
    if session_uuid != nil do
      pipe
      |> Mongo.replace_one(coll, %{"_id" => bson_doc_id}, filtered_doc,
        session: Swarm.whereis_name(session_uuid)
      )
    else
      pipe
      |> Mongo.replace_one(coll, %{"_id" => bson_doc_id}, filtered_doc)
    end
  end

  @spec delete_doc(number(), String.t(), String.t()) :: :ok | {:error, TechnicalErrorType.t()}
  def delete_doc(env_id, coll, doc_id, session_uuid \\ nil) do
    with {:ok, bson_doc_id} <- decode_object_id(doc_id) do
      env_id
      |> mongo_instance()
      |> handle_delete_doc(session_uuid, coll, bson_doc_id)
      |> case do
        {:error, err} ->
          TechnicalError.mongo_error_tuple(err)

        _res ->
          :ok
      end
    end
  end

  defp handle_delete_doc(pipe, session_uuid, coll, bson_doc_id) do
    if session_uuid != nil do
      pipe
      |> Mongo.delete_one(coll, %{"_id" => bson_doc_id}, session: Swarm.whereis_name(session_uuid))
    else
      pipe
      |> Mongo.delete_one(coll, %{"_id" => bson_doc_id})
    end
  end

  @object_id_regex ~r/^ObjectId\(([[:xdigit:]]{24})\)$/

  def decode_object_id(str) do
    case Regex.run(@object_id_regex, str) do
      nil ->
        BusinessError.not_an_object_id_tuple()

      [_, hex_id] ->
        case BSON.ObjectId.decode(hex_id) do
          :error ->
            BusinessError.not_an_object_id_tuple()

          res ->
            res
        end
    end
  end

  @spec decode_ids(term()) :: term()
  def decode_ids(str) when is_bitstring(str) do
    case decode_object_id(str) do
      {:ok, id} -> id
      _err -> str
    end
  end

  def decode_ids(query) when is_list(query) do
    Enum.map(query, &decode_ids(&1))
  end

  def decode_ids(query) when is_map(query) do
    query
    |> Enum.map(fn {k, v} -> {k, decode_ids(v)} end)
    |> Map.new()
  end

  def decode_ids(query) do
    query
  end

  #############
  # Coll      #
  #############

  @spec delete_coll(number(), String.t()) :: :ok | TechnicalErrorType.t()
  def delete_coll(env_id, coll) do
    env_id
    |> mongo_instance()
    |> Mongo.drop_collection(coll)
    |> case do
      {:error, err} -> TechnicalError.mongo_error(err)
      :ok -> :ok
    end
  end

  ####################
  # Transaction      #
  ####################

  def start_transaction(env_id) do
    with pid when is_pid(pid) <- Swarm.whereis_name(mongo_instance(env_id)) |> IO.inspect(),
         {:ok, session_pid} <- Mongo.Session.start_session(mongo_instance(env_id), :write),
         session_uuid <- Ecto.UUID.generate(),
         :yes <- Swarm.register_name(session_uuid, session_pid),
         :ok <- Mongo.Session.start_transaction(session_pid) do
      {:ok, session_uuid}
    else
      :no ->
        BusinessError.error_during_transaction_start_tuple(%{
          error: "uuid already used, plesa try again"
        })

      :undefined ->
        BusinessError.mongo_not_started_tuple()

      {:error, msg} ->
        BusinessError.error_during_transaction_start_tuple(%{error_message: msg})
    end
  end

  def commit_transaction(session_uuid, env_id) do
    with :ok <- Mongo.Session.commit_transaction(Swarm.whereis_name(session_uuid)),
         :ok <-
           Mongo.Session.end_session(mongo_instance(env_id), Swarm.whereis_name(session_uuid)) do
      :ok
    else
      # TODO: check what to do in this case
      _any ->
        :error
    end
  end

  def revert_transaction(session_uuid, env_id) do
    with :ok <- Mongo.Session.abort_transaction(Swarm.whereis_name(session_uuid)),
         :ok <-
           Mongo.Session.end_session(mongo_instance(env_id), Swarm.whereis_name(session_uuid)) do
      :ok
    else
      # TODO: check what to do in this case
      _any -> :error
    end
  end
end
