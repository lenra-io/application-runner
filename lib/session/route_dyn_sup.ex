defmodule ApplicationRunner.Session.RouteDynSup do
  @moduledoc """
    This module is responsible to start the QueryServer for a given env_id.
    If the query server is already started, it act like it just started.
    It also add the QueryServer to the correct group after it started it.
  """
  use DynamicSupervisor
  use SwarmNamed

  alias ApplicationRunner.Session.{RouteServer, RouteSupervisor}

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    DynamicSupervisor.start_link(__MODULE__, :ok, name: get_full_name(session_id))
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec ensure_child_started(term(), String.t(), String.t(), String.t()) ::
          {:ok, pid()} | {:error, term()}
  def ensure_child_started(env_id, session_id, mode, route) do
    case start_child(env_id, session_id, mode, route) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        route_server_name = RouteServer.get_full_name({session_id, mode, route})
        GenServer.cast(route_server_name, :resync)
        {:ok, pid}

      err ->
        err
    end
  end

  defp start_child(env_id, session_id, mode, route) do
    init_value = [
      route: route,
      mode: mode,
      session_id: session_id,
      env_id: env_id
    ]

    case DynamicSupervisor.start_child(get_full_name(session_id), {RouteSupervisor, init_value}) do
      {:error, {:shutdown, {:failed_to_start_child, _module, reason}}} ->
        {:error, reason}

      res ->
        res
    end
  end
end
