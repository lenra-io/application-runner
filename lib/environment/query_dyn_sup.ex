defmodule ApplicationRunner.Environment.QueryDynSup do
  use DynamicSupervisor

  alias ApplicationRunner.Environment.QueryServer

  def start_link(opts) do
    env_id = Keyword.get(opts, :env_id)
    DynamicSupervisor.start_link(__MODULE__, :ok, name: {:via, :swarm, get_name(env_id)})
  end

  def get_name(env_id) do
    {__MODULE__, env_id}
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_child_started(env_id, session_id, coll, query, opts \\ []) do
    case start_child(env_id, coll, query, opts) do
      {:ok, pid} ->
        group = QueryServer.get_group(session_id)
        Swarm.join(group, pid)
        :ok

      {:error, {:already_started, pid}} ->
        group = QueryServer.get_group(session_id)

        Swarm.join(group, pid)
        :ok

      err ->
        err
    end
  end

  defp start_child(env_id, coll, query, opts \\ []) do
    init_value = Keyword.merge(opts, query: query, coll: coll, env_id: env_id)
    DynamicSupervisor.start_child(__MODULE__, {QueryServer, init_value})
  end
end
