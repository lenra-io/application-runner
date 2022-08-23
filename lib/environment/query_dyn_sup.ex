defmodule ApplicationRunner.Environment.QueryDynSup do
  @moduledoc """
    This module is responsible to start the QueryServer for a given env_id.
    If the query server is already started, it act like it just started.
    It also add the QueryServer to the correct group after it started it.
  """
  use DynamicSupervisor
  use SwarmNamed

  alias ApplicationRunner.Environment.QueryServer

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    DynamicSupervisor.start_link(__MODULE__, :ok, name: get_full_name(env_id))
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_child_started(env_id, session_id, coll, query, opts \\ []) do
    case start_child(env_id, coll, query, opts) do
      {:ok, pid} ->
        join_group(session_id, pid)
        :ok

      {:error, {:already_started, pid}} ->
        join_group(session_id, pid)
        :ok

      err ->
        err
    end
  end

  defp join_group(session_id, pid) do
    group = QueryServer.group_name(session_id)
    Swarm.join(group, pid)
  end

  defp start_child(env_id, coll, query, opts \\ []) do
    init_value = Keyword.merge(opts, query: query, coll: coll, env_id: env_id)
    DynamicSupervisor.start_child(get_full_name(env_id), {QueryServer, init_value})
  end
end
