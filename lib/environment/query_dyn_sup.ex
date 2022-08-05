defmodule ApplicationRunner.Environment.QueryDynSup do
  use DynamicSupervisor

  alias ApplicationRunner.Environment.QueryServer

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(coll, query, session_id) do
    DynamicSupervisor.start_child(__MODULE__, {QueryServer, query: query, coll: coll})
  end

  def ensure_child_started(coll, query, session_id) do
    case start_child(coll, query, session_id) do
      {:ok, pid} ->
        Swarm.join({:query, session_id}, pid)
        :ok

      {:error, {:already_started, pid}} ->
        Swarm.join({:query, session_id}, pid)
        :ok

      err ->
        err
    end
  end
end
