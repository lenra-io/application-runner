defmodule ApplicationRunner.EnvManager do
  @moduledoc """
    This module handles one application. This module is the root_widget to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManagers,
    EnvState,
    EnvSupervisor,
    EventHandler
  }

  @spec get_manifest(number()) :: map()
  def get_manifest(env_id) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :get_manifest)
    end
  end

  def wait_until_ready(env_id) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :wait_until_ready)
    end
  end

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)

    with {:ok, pid} <-
           GenServer.start_link(__MODULE__, opts, name: {:via, :swarm, {:env, env_id}}) do
      Swarm.join(:envs, pid)
      {:ok, pid}
    end
  end

  @impl true
  def init(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    assigns = Keyword.fetch!(opts, :assigns)

    {:ok, env_supervisor_pid} = EnvSupervisor.start_link(nil)
    # Link the process to kill the manager if the supervisor is killed.
    # The EnvManager should be restarted by the EnvManagers then it will restart the supervisor.
    Process.link(env_supervisor_pid)

    event_handler_pid = EnvSupervisor.fetch_module_pid!(env_supervisor_pid, EventHandler)
    EventHandler.subscribe(event_handler_pid)

    env_state = %EnvState{
      env_id: env_id,
      assigns: assigns,
      env_supervisor_pid: env_supervisor_pid,
      inactivity_timeout:
        Application.get_env(:application_runner, :env_inactivity_timeout, 1000 * 60 * 60),
      ready?: false,
      waiting_pid: []
    }

    with {:ok, manifest} <- AdapterHandler.get_manifest(env_state),
         env_state <- Map.put(env_state, :manifest, manifest) do
      {:ok, env_state, {:continue, :after_init}}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:after_init, env_state) do
    send_on_env_start_event(env_state)
    {:noreply, env_state}
  end

  @impl true
  def handle_call(:get_manifest, _from, env_state) do
    {:reply, Map.get(env_state, :manifest), env_state, env_state.inactivity_timeout}
  end

  def handle_call(:wait_until_ready, {pid, _}, env_state) do
    ready? = Map.get(env_state, :ready?)

    if ready? do
      {:reply, :ok, env_state, env_state.inactivity_timeout}
    else
      waiting_pid = Map.get(env_state, :waiting_pid, [])
      env_state = Map.put(env_state, :waiting_pid, [pid, waiting_pid])
      {:noreply, env_state, env_state.inactivity_timeout}
    end
  end

  def handle_call(:fetch_env_supervisor_pid!, _from, env_state) do
    case Map.get(env_state, :env_supervisor_pid) do
      nil -> raise "No EnvSupervisor. This should not happen."
      res -> {:reply, res, env_state, env_state.inactivity_timeout}
    end
  end

  def handle_call({:swarm, :begin_handoff}, _from, state) do
    {:reply, :restart, state}
  end

  def handle_call(:stop, from, env_state) do
    stop(env_state, from)
    {:reply, :ok, env_state}
  end

  @impl true
  def handle_info(:timeout, env_state) do
    stop(env_state, nil)
    {:noreply, env_state}
  end

  def handle_info({:event_finished, "onEnvStart", result}, env_state) do
    waiting_pid = Map.get(env_state, :waiting_pid, [])
    Enum.each(waiting_pid, fn pid -> GenServer.reply(pid, result) end)

    env_state =
      env_state
      |> Map.put(:ready?, true)
      |> Map.put(:waiting_pid, [])

    {:noreply, env_state}
  end

  def handle_info({:event_finished, _action, _result}, env_state) do
    {:noreply, env_state}
  end

  defp do_send_event(env_state, action, props, event) do
    event_handler_pid =
      EnvSupervisor.fetch_module_pid!(env_state.env_supervisor_pid, EventHandler)

    EventHandler.send_event(event_handler_pid, env_state, action, props, event)
  end

  defp send_on_env_start_event(env_state),
    do: do_send_event(env_state, "onEnvStart", %{}, %{})

  defp send_on_env_stop_event(env_state),
    do: do_send_event(env_state, "onEnvStop", %{}, %{})

  defp stop(%EnvState{} = env_state, from) do
    # Stop all the session node for the given app and stop the app.
    Swarm.multi_call({:sessions, env_state.env_id}, :stop)
    send_on_env_stop_event(env_state)
    if not is_nil(from), do: GenServer.reply(from, :ok)
    EnvManagers.terminate_app(self())
  end
end
