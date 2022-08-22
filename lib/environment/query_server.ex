defmodule ApplicationRunner.Environment.QueryServer do
  @moduledoc """
    This module take care of updating a data to sync with the database.
    - It get the initial data from the mongo db using coll/query.
    - It wait for the Session Change Event and update the data accordingly
    - It use QueryParser to check if the new data actually match the query.
    - If the data is updated, it notify the Widget group using Swarm.publish
  """
  use GenServer

  alias LenraCommon.Errors.{DevError, TechnicalError}
  alias ApplicationRunner.Environment.{MongoInstance, Widget}
  alias QueryParser.{Exec, Parser}

  require Logger

  @inactivity_timeout Application.compile_env(
                        :application_runner,
                        :query_inactivity_timeout,
                        1000 * 60 * 10
                      )

  def start_link(opts) do
    with {:ok, query} <- Keyword.fetch(opts, :query),
         {:ok, coll} <- Keyword.fetch(opts, :coll),
         {:ok, env_id} <- Keyword.fetch(opts, :env_id) do
      GenServer.start_link(__MODULE__, opts, name: get_full_name(env_id, coll, query))
    else
      :error ->
        DevError.exception(message: "QueryServer need a collection, a query and an env_id")
    end
  end

  def get_full_name(env_id, coll, query) do
    {:via, :swarm, get_name(env_id, coll, query)}
  end

  def get_name(env_id, coll, query) do
    {__MODULE__, env_id, coll, query}
  end

  def group_name(session_id) do
    {__MODULE__, session_id}
  end

  def init(opts) do
    with {:ok, env_id} <- Keyword.fetch(opts, :env_id),
         {:ok, query} <- Keyword.fetch(opts, :query),
         {:ok, coll} <- Keyword.fetch(opts, :coll),
         {:ok, query_map} <- Poison.decode(query),
         {:ok, data} <- fetch_initial_data(env_id, coll, query_map),
         {:ok, ast} <- Parser.parse(query, %{}) do
      inactivity_timeout = Keyword.get(opts, :inactivity_timeout, @inactivity_timeout)

      {:ok,
       %{
         data: data,
         query_str: query,
         env_id: env_id,
         query: ast,
         coll: coll,
         inactivity_timeout: inactivity_timeout,
         latest_timestamp: 0,
         done_ids: []
       }, inactivity_timeout}
    else
      {:error, err} ->
        {:stop, err}
    end
  end

  def fetch_initial_data(env_id, coll, query) do
    mongo_name = MongoInstance.get_full_name(env_id)

    case Mongo.find(mongo_name, coll, query) do
      {:error, term} -> TechnicalError.mongo_data_fetch_error_tuple(term)
      cursor -> {:ok, Enum.to_list(cursor)}
    end
  end

  def handle_call(
        {:mongo_event, event},
        _from,
        state
      ) do
    event_timestamp = get_in(event, ["clusterTime"])
    event_id = get_in(event, ["_id"])

    if event_handled?(event_id, event_timestamp, state) do
      # The event is already handled. Reply directly and ignore event.s
      reply_timeout(:ok, state)
    else
      # The event must be handled.
      handle_event(event, event_id, event_timestamp, state)
    end
  end

  defp event_handled?(
         event_id,
         event_timestamp,
         %{
           latest_timestamp: latest_timestamp,
           done_ids: done_ids
         }
       ) do
    event_timestamp < latest_timestamp or event_id in done_ids
  end

  defp handle_event(
         event,
         event_id,
         event_timestamp,
         %{
           latest_timestamp: latest_timestamp,
           done_ids: done_ids,
           query: query,
           data: data,
           coll: coll
         } = state
       ) do
    event_coll = get_in(event, ["ns", "coll"])
    op_type = get_in(event, ["operationType"])

    cond do
      event_coll == coll and op_type in ["insert", "update", "replace", "delete"] ->
        full_doc = get_in(event, ["fullDocument"])
        doc_id = get_in(event, ["documentKey", "_id"])

        new_data = change_data(op_type, full_doc, doc_id, data, query, state)
        new_done_ids = get_new_done_ids(event_timestamp, latest_timestamp, event_id, done_ids)

        new_state =
          Map.merge(state, %{
            data: new_data,
            done_ids: new_done_ids,
            latest_timestamp: event_timestamp
          })

        reply_timeout(:ok, new_state)

      event_coll == coll and op_type in ["rename"] ->
        change_coll(op_type, event, state)

      event_coll == coll and op_type in ["drop"] ->
        stop(state)

      op_type in ["dropDatabase"] ->
        stop(state)

      true ->
        reply_timeout(:ok, state)
    end
  end

  defp get_new_done_ids(event_timestamp, latest_timestamp, event_id, done_ids) do
    if event_timestamp > latest_timestamp, do: [event_id], else: [event_id | done_ids]
  end

  defp change_coll(
         "rename",
         %{"ns" => %{"coll" => old_coll}, "to" => %{"coll" => new_coll}},
         %{query_str: query_str, env_id: env_id} = state
       ) do
    # Since the genserver name depend on coll, we change the name if the coll change.
    # Unregister old name
    Swarm.unregister_name(get_name(env_id, old_coll, query_str))
    # Register new name
    Swarm.register_name(get_name(env_id, new_coll, query_str), self())
    notify_coll_changed(new_coll, state)
    reply_timeout(:ok, Map.put(state, :coll, new_coll))
  end

  defp change_coll(op_type, _event, _state) do
    raise DevError.exception("Could not handle #{op_type} event.")
  end

  defp stop(state) do
    {:stop, :normal, :ok, state}
  end

  defp stop_async(state) do
    {:stop, :normal, state}
  end

  defp change_data("insert", full_doc, _doc_id, data, query, state) do
    if Exec.match?(full_doc, query) do
      new_data = data ++ [full_doc]
      notify_data_changed(new_data, state)
      new_data
    else
      data
    end
  end

  defp change_data(op_type, full_doc, doc_id, data, query, state)
       when op_type in ["update", "replace"] do
    if Exec.match?(full_doc, query) do
      new_data =
        Enum.map(data, fn
          %{"_id" => ^doc_id} -> full_doc
          d -> d
        end)

      notify_data_changed(new_data, state)
      new_data
    else
      old_length = length(data)
      new_data = Enum.reject(data, fn %{"_id" => id} -> id == doc_id end)

      if old_length == length(new_data) do
        data
      else
        notify_data_changed(new_data, state)
        new_data
      end
    end
  end

  defp change_data("delete", _full_doc, doc_id, data, _query, state) do
    new_data = Enum.reject(data, fn doc -> Map.get(doc, "_id") == doc_id end)
    notify_data_changed(new_data, state)
    new_data
  end

  defp change_data(op_type, _full_doc, _doc_id, _data, _query, state) do
    Logger.debug("Ingore event #{op_type}")
    reply_timeout(:ok, state)
  end

  defp notify_data_changed(new_data, %{env_id: env_id, query_str: query_str, coll: coll}) do
    group = Widget.get_widget_group(env_id, coll, query_str)
    Swarm.publish(group, {:data_changed, new_data})
  end

  defp notify_coll_changed(new_coll, %{env_id: env_id, query_str: query_str, coll: old_coll}) do
    group = Widget.get_widget_group(env_id, old_coll, query_str)
    Swarm.publish(group, {:coll_changed, new_coll})
  end

  defp reply_timeout(res, state) do
    {:reply, res, state, state.inactivity_timeout}
  end

  def handle_info(:timeout, state) do
    stop_async(state)
  end
end
