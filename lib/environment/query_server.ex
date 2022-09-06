defmodule ApplicationRunner.Environment.QueryServer do
  @moduledoc """
    This module take care of updating a data to sync with the database.
    - It get the initial data from the mongo db using coll/query.
    - It wait for the Session Change Event and update the data accordingly
    - It use QueryParser to check if the new data actually match the query.
    - If the data is updated, it notify the Widget group using Swarm.publish
  """
  use GenServer
  use SwarmNamed

  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.Environment.{MongoInstance, WidgetServer}
  alias LenraCommon.Errors.DevError
  alias QueryParser.{Exec, Parser}

  require Logger

  def start_link(opts) do
    with {:ok, query} <- Keyword.fetch(opts, :query),
         {:ok, coll} <- Keyword.fetch(opts, :coll),
         {:ok, env_id} <- Keyword.fetch(opts, :env_id) do
      GenServer.start_link(__MODULE__, opts, name: get_full_name({env_id, coll, query}))
    else
      :error ->
        DevError.exception(message: "QueryServer need a collection, a query and an env_id")
    end
  end

  def group_name(session_id) do
    {__MODULE__, session_id}
  end

  def join_group(pid, session_id) do
    group = group_name(session_id)
    Swarm.join(group, pid)
  end

  def get_data(env_id, coll, query) do
    GenServer.call(get_full_name({env_id, coll, query}), :get_data)
  end

  @doc """
    Start monotoring the given WidgetServer
  """
  def monitor(qs_pid, w_pid) do
    GenServer.call(qs_pid, {:monitor, w_pid})
  end

  # I cant figure a way to fix the warning throw by Parser...
  @dialyzer {:no_match, init: 1}

  def init(opts) do
    with {:ok, env_id} <- Keyword.fetch(opts, :env_id),
         {:ok, query} <- Keyword.fetch(opts, :query),
         {:ok, coll} <- Keyword.fetch(opts, :coll),
         {:ok, query_map} <- decode_query(query),
         {:ok, data} <- fetch_initial_data(env_id, coll, query_map),
         {:ok, ast} <- parse_query(query, %{}) do
      {:ok,
       %{
         data: data,
         map_data: to_map_data(data),
         query_str: query,
         env_id: env_id,
         query: ast,
         coll: coll,
         latest_timestamp: Mongo.timestamp(DateTime.utc_now()),
         done_ids: MapSet.new(),
         w_pids: MapSet.new()
       }}
    else
      :error ->
        raise DevError.exception("Missing data in opts (#{inspect(opts)}")

      {:error, err} ->
        IO.inspect(err)
        {:stop, err}
    end
  end

  defp to_map_data(data) do
    Map.new(data, fn d -> {Map.get(d, "_id"), d} end)
  end

  defp from_map_data(map_data) do
    Map.values(map_data)
  end

  defp parse_query(nil, _params) do
    {:ok, nil}
  end

  defp parse_query(query, params) do
    Parser.parse(query, params) |> IO.inspect()
  end

  defp decode_query(nil) do
    {:ok, nil}
  end

  defp decode_query(query) do
    Poison.decode(query)
  end

  defp fetch_initial_data(_env_id, coll, query) when is_nil(coll) or is_nil(query) do
    {:ok, []}
  end

  defp fetch_initial_data(env_id, coll, query) do
    mongo_name = MongoInstance.get_full_name(env_id)

    case Mongo.find(mongo_name, coll, query) do
      {:error, term} -> TechnicalError.mongo_error_tuple(term)
      cursor -> {:ok, Enum.to_list(cursor)}
    end
  end

  def handle_call({:mongo_event, _event}, _from, %{coll: coll, query: query} = state)
      when is_nil(coll) or is_nil(query) do
    {:reply, :ok, state}
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
      {:reply, :ok, state}
    else
      # The event must be handled.
      handle_event(event, event_id, event_timestamp, state)
    end
  end

  def handle_call(:get_data, _from, state) do
    {:reply, Map.get(state, :data), state}
  end

  def handle_call({:monitor, w_pid}, _from, state) do
    Process.monitor(w_pid)
    new_w_ids = MapSet.put(state.w_pids, w_pid)
    {:reply, :ok, Map.put(state, :w_pids, new_w_ids)}
  end

  defp event_handled?(
         event_id,
         event_timestamp,
         %{
           latest_timestamp: latest_timestamp,
           done_ids: done_ids
         }
       ) do
    BSON.Timestamp.is_before(event_timestamp, latest_timestamp) or event_id in done_ids
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
           map_data: map_data,
           coll: coll
         } = state
       ) do
    event_coll = get_in(event, ["ns", "coll"])
    op_type = get_in(event, ["operationType"])

    cond do
      event_coll == coll and op_type in ["insert", "update", "replace", "delete"] ->
        full_doc = get_in(event, ["fullDocument"])
        doc_id = get_in(event, ["documentKey", "_id"])

        {new_map_data, new_data} =
          change_data(op_type, full_doc, doc_id, data, map_data, query, state)

        new_done_ids = get_new_done_ids(event_timestamp, latest_timestamp, event_id, done_ids)

        new_state =
          Map.merge(state, %{
            data: new_data,
            map_data: new_map_data,
            done_ids: new_done_ids,
            latest_timestamp: event_timestamp
          })

        {:reply, :ok, new_state}

      event_coll == coll and op_type in ["rename"] ->
        change_coll(op_type, event, state)

      event_coll == coll and op_type in ["drop"] ->
        stop(state)

      op_type in ["dropDatabase"] ->
        stop(state)

      true ->
        {:reply, :ok, state}
    end
  end

  defp get_new_done_ids(event_timestamp, latest_timestamp, event_id, done_ids) do
    if BSON.Timestamp.is_before(event_timestamp, latest_timestamp),
      do: MapSet.put(done_ids, event_id),
      else: MapSet.new([event_id])
  end

  defp change_coll(
         "rename",
         %{"ns" => %{"coll" => old_coll}, "to" => %{"coll" => new_coll}},
         %{query_str: query_str, env_id: env_id} = state
       ) do
    # Since the genserver name depend on coll, we change the name if the coll change.
    # Unregister old name
    Swarm.unregister_name(get_name({env_id, old_coll, query_str}))
    # Register new name
    Swarm.register_name(get_name({env_id, new_coll, query_str}), self())
    notify_coll_changed(new_coll, state)
    {:reply, :ok, Map.put(state, :coll, new_coll)}
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

  defp change_data("insert", full_doc, doc_id, data, map_data, query, state) do
    if Exec.match?(full_doc, query) do
      new_map_data = Map.put(map_data, doc_id, full_doc)
      new_data = from_map_data(new_map_data)
      notify_data_changed(new_data, state)
      {new_map_data, new_data}
    else
      {map_data, data}
    end
  end

  defp change_data(op_type, full_doc, doc_id, data, map_data, query, state)
       when op_type in ["update", "replace"] do
    if Exec.match?(full_doc, query) do
      new_map_data = Map.put(map_data, doc_id, full_doc)
      new_data = from_map_data(new_map_data)

      notify_data_changed(new_data, state)
      {new_map_data, new_data}
    else
      old_length = Enum.count(map_data)
      new_map_data = Map.delete(map_data, doc_id)

      if old_length == Enum.count(new_map_data) do
        {map_data, data}
      else
        new_data = from_map_data(new_map_data)
        notify_data_changed(new_data, state)
        {new_map_data, new_data}
      end
    end
  end

  defp change_data("delete", _full_doc, doc_id, _data, map_data, _query, state) do
    new_map_data = Map.delete(map_data, doc_id)
    new_data = from_map_data(new_map_data)
    notify_data_changed(new_data, state)
    {new_map_data, new_data}
  end

  defp change_data(op_type, _full_doc, _doc_id, _data, _map_data, _query, state) do
    Logger.debug("Ingore event #{op_type}")
    {:reply, :ok, state}
  end

  defp notify_data_changed(new_data, %{env_id: env_id, query_str: query_str, coll: coll}) do
    group = WidgetServer.group_name(env_id, coll, query_str)
    Swarm.publish(group, {:data_changed, new_data})
  end

  defp notify_coll_changed(new_coll, %{env_id: env_id, query_str: query_str, coll: old_coll}) do
    group = WidgetServer.group_name(env_id, old_coll, query_str)
    Swarm.publish(group, {:coll_changed, new_coll})
  end

  # If a WidgetServer die, we receive a message here.
  # If there is no more monitored WidgetServer, we stop this QueryServer.
  def handle_info({:DOWN, _ref, :process, w_pid, _reason}, state) do
    new_w_pids = MapSet.delete(state.w_pids, w_pid)

    if MapSet.size(new_w_pids) == 0 do
      stop_async(state)
    else
      {:noreply, Map.put(state, :w_pids, new_w_pids)}
    end
  end
end
