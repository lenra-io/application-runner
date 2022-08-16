defmodule Environment.Mongo.Session.DynamicSupervisor do
  use DynamicSupervisor

  alias ApplicationRunner.Environment.Mongo.Session

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_child_started(session_id) do
    case start_child(session_state) do
      {:ok, pid} ->
        Swarm.join(name, pid)
        :ok

      {:error, {:already_started, pid}} ->
        Swarm.join(name, pid)
        :ok

      err ->
        err
    end
  end

  defp start_child(session_state) do
    init_value = [session_state: session_state]

    DynamicSupervisor.start_child(__MODULE__, {Session, init_value})
  end

  def stop_child(session_id) do
    GenServer.call({:global, {:mongo_session, session_id}}, :stop)
  end
end
