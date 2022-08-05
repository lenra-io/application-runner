defmodule ApplicationRunner.Environment.QueryServer do
  use GenServer

  alias LenraCommon.Errors.DevError
  alias QueryParser.{Parser, Exec}

  def start_link(opts) do
    query = Keyword.get(opts, :query)
    coll = Keyword.get(opts, :coll)
    GenServer.start_link(__MODULE__, opts, name: {:via, :swarm, get_name(query, coll)})
  end

  def get_name(query, coll) do
    hash = Crypto.hash({query, coll})
    {ApplicationRunner.Environment.QueryServer, hash}
  end

  def init(opts) do
    with {:ok, query} <- Keyword.fetch(opts, :query),
         {:ok, coll} <- Keyword.fetch(opts, :coll),
         {:ok, data} <- fetch_initial_data(coll, query),
         {:ok, ast} <- Parser.parse(query, %{}) do
      {:ok, %{data: data, query: ast, coll: coll}}
    else
      {:error, err} ->
        {:stop, err}

      :error ->
        {:stop, DevError.exception(message: "QueryServer need a collection and a query")}
    end
  end

  def fetch_initial_data(_coll, _query) do
    {:ok, []}
  end

  #   {
  #     _id : { <BSON Object> },
  #     "operationType" : "<operation>",
  #     "fullDocument" : { <document> },
  #     "ns" : {
  #        "db" : "<database>",
  #        "coll" : "<collection>"
  #     }
  #  }

  def handle_call(
        {:mongo_event, event},
        _from,
        %{coll: coll, data: data, query: query} = state
      ) do
    event_coll = get_in(event, ["ns", "coll"])
    op_type = get_in(event, ["operationType"])

    cond do
      event_coll == coll and op_type in ["insert", "update", "replace", "delete"] ->
        full_doc = get_in(event, ["fullDocument"])
        doc_id = get_in(event, ["documentKey", "_id"])
        change_data(op_type, full_doc, doc_id, data, query, state)

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

  defp change_coll(
         "rename",
         %{"ns" => %{"coll" => _old_coll}, "to" => %{"coll" => new_coll}},
         state
       ) do
    {:reply, :ok, Map.put(state, :coll, new_coll)}
  end

  defp change_coll(op_type, _event, _state) do
    raise DevError.exception("Could not handle #{op_type} event.")
  end

  defp stop(state) do
    {:stop, :normal, :ok, state}
  end

  defp change_data("insert", full_doc, _doc_id, data, query, state) do
    new_data = if Exec.match?(full_doc, query), do: data ++ [full_doc], else: data
    {:reply, :ok, Map.put(state, :data, new_data)}
  end

  defp change_data(opType, full_doc, doc_id, data, query, state)
       when opType in ["update", "replace"] do
    new_data =
      if Exec.match?(full_doc, query) do
        Enum.map(data, fn
          %{"_id" => ^doc_id} -> full_doc
          d -> d
        end)
      else
        Enum.reject(data, fn %{"_id" => id} -> id == doc_id end)
      end

    {:reply, :ok, Map.put(state, :data, new_data)}
  end

  defp change_data("delete", _full_doc, doc_id, data, _query, state) do
    new_data = Enum.reject(data, fn doc -> Map.get(doc, "_id") == doc_id end)
    {:reply, :ok, Map.put(state, :data, new_data)}
  end

  defp change_data(op_type, _full_doc, _doc_id, _data, _query, _state) do
    raise DevError.exception("Could not handle #{op_type} event.")
  end
end
