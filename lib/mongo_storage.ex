defmodule ApplicationRunner.MongoStorage do
  @moduledoc """
    ApplicationRunner.JsonStorage handles all data logic.
    We can find delegate function to associate Services.
  """
  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.Environment
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.MongoStorage.MongoUserLink
  alias LenraCommon.Errors.TechnicalError, as: TechnicalErrorType

  import Ecto.Query

  @repo Application.compile_env(:application_runner, :repo)

  defp mongo_instance(env_id) do
    Environment.MongoInstance.get_full_name(env_id)
  end

  #################
  # MongoUserLink #
  #################

  @spec get_mongo_user_link!(number(), number()) :: any
  def get_mongo_user_link!(env_id, user_id) do
    @repo.one!(
      from(mul in MongoUserLink, where: mul.user_id == ^user_id and mul.environment_id == ^env_id)
    )
  end

  def has_user_link?(env_id, user_id) do
    query =
      from(u in MongoUserLink,
        where: u.user_id == ^user_id and u.environment_id == ^env_id
      )

    @repo.exists?(query)
  end

  def create_user_link(%{environment_id: _, user_id: _} = params) do
    MongoUserLink.new(params)
    |> @repo.insert()
  end

  ########
  # DATA #
  ########

  # defdelegate create_data(environment_id, params), to: Services.Data, as: :create

  @spec create_doc(number(), String.t(), map()) :: :ok | {:error, TechnicalErrorType.t()}
  def create_doc(env_id, coll, doc) do
    env_id
    |> mongo_instance()
    |> Mongo.insert_one(coll, doc)
    |> case do
      {:error, err} ->
        TechnicalError.mongo_error_tuple(err)

      _res ->
        :ok
    end
  end

  # defdelegate parse_and_exec_query(env_id, coll, query),
  #   to: Services.Data,
  #   as: :parse_and_exec_query

  @spec fetch_doc(number(), String.t(), String.t()) ::
          {:ok, map()} | {:error, TechnicalErrorType.t()}
  def fetch_doc(env_id, coll, doc_id) do
    with {:ok, bson_doc_id} <- BSON.ObjectId.decode(doc_id) do
      env_id
      |> mongo_instance()
      |> Mongo.find_one(coll, %{"_id" => bson_doc_id})
      |> case do
        {:error, err} -> TechnicalError.mongo_error_tuple(err)
        res -> {:ok, res}
      end
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
    env_id
    |> mongo_instance()
    |> Mongo.find(coll, filter)
    |> case do
      {:error, err} ->
        TechnicalError.mongo_error_tuple(err)

      cursor ->
        {:ok, Enum.to_list(cursor)}
    end
  end

  @spec update_doc(number(), String.t(), String.t(), map()) ::
          :ok | {:error, TechnicalErrorType.t()}
  def update_doc(env_id, coll, doc_id, new_doc) do
    with {:ok, bson_doc_id} <- BSON.ObjectId.decode(doc_id) do
      env_id
      |> mongo_instance()
      |> Mongo.replace_one(coll, %{"_id" => bson_doc_id}, new_doc)
      |> case do
        {:error, err} ->
          TechnicalError.mongo_error_tuple(err)

        _res ->
          :ok
      end
    end
  end

  @spec delete_doc(number(), String.t(), String.t()) :: :ok | {:error, TechnicalErrorType.t()}
  def delete_doc(env_id, coll, doc_id) do
    with {:ok, bson_doc_id} <- BSON.ObjectId.decode(doc_id) do
      env_id
      |> mongo_instance()
      |> Mongo.delete_one(coll, %{"_id" => bson_doc_id})
      |> case do
        {:error, err} ->
          TechnicalError.mongo_error_tuple(err)

        _res ->
          :ok
      end
    end
  end

  #############
  # DATASTORE #
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

  #############
  # USERDATA #
  #############

  # defdelegate create_user_data(params), to: Services.UserData, as: :create

  # defdelegate create_user_data_with_data(env_id, user_id),
  #   to: Services.UserData,
  #   as: :create_with_data

  # defdelegate has_user_data?(env_id, user_id), to: Services.UserData, as: :has_user_data?

  # defdelegate current_user_data_query(env_id, user_id),
  #   to: Services.UserData,
  #   as: :current_user_data_query

  ##################
  # DATA REFERENCE #
  ##################

  # defdelegate create_reference(params), to: Services.DataReferences, as: :create

  # defdelegate delete_reference(params),
  #   to: Services.DataReferences,
  #   as: :delete

  ##############
  # QUERY VIEW #
  ##############

  # defdelegate get_one(env_id, datastore_name, data_id), to: Services.DataQueryView, as: :get_one

  # defdelegate get_all(env_id, datastore_name), to: Services.DataQueryView, as: :get_all
end
