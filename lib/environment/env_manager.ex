defmodule ApplicationRunner.EnvManager do
  @moduledoc """
    This module handles one application. This module is the root_widget to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    AdapterHandler,
    EnvManagers,
    EnvState,
    EnvSupervisor
  }

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

    env_state = %EnvState{
      env_id: env_id,
      assigns: assigns,
      env_supervisor_pid: env_supervisor_pid,
      inactivity_timeout:
        Application.get_env(:application_runner, :env_inactivity_timeout, 1000 * 60 * 60)
    }

    with {:ok, manifest} <- AdapterHandler.get_manifest(env_state),
         env_state <- Map.put(env_state, :manifest, manifest),
         :ok <- send_on_env_start_event(env_state) do
      {:ok, env_state, env_state.inactivity_timeout}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @spec get_manifest(number()) :: map()
  def get_manifest(env_id) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :get_manifest)
    end
  end

  @spec fetch_assigns(number()) :: {:ok, any()} | {:error, :env_not_started}
  def fetch_assigns(env_id) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :fetch_assigns)
    end
  end

  @spec(set_assigns(number(), term()) :: :ok, {:error, :env_not_started})
  def set_assigns(env_id, assigns) do
    with {:ok, pid} <- EnvManagers.fetch_env_manager_pid(env_id) do
      GenServer.cast(pid, {:set_assigns, assigns})
    end
  end

  def send_on_env_start_event(env_state),
    do: do_send_special_event(env_state, "onEnvStart", %{}, %{})

  def send_on_env_stop_event(env_state),
    do: do_send_special_event(env_state, "onEnvStop", %{}, %{})

  @impl true
  def handle_call(:get_manifest, _from, env_state) do
    {:reply, Map.get(env_state, :manifest), env_state, env_state.inactivity_timeout}
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

  def handle_call(:fetch_assigns, _from, env_state) do
    {:reply, {:ok, env_state.assigns}, env_state}
  end

  def handle_call(:stop, from, env_state) do
    stop(env_state, from)
    {:reply, :ok, env_state}
  end

  @impl true
  def handle_cast({:send_special_event, action, event}, env_state) do
    do_send_special_event(env_state, action, %{}, event)

    {:noreply, env_state, env_state.inactivity_timeout}
  end

  def handle_cast({:set_assigns, assigns}, env_state) do
    {:noreply, Map.put(env_state, :assigns, assigns)}
  end

  @impl true
  def handle_info(:timeout, env_state) do
    stop(env_state, nil)
    {:noreply, env_state}
  end

  defp do_send_special_event(env_state, action, props, event) do
    AdapterHandler.run_listener(env_state, action, props, event)
  end

  defp stop(%EnvState{} = env_state, from) do
    # Stop all the session node for the given app and stop the app.
    Swarm.multi_call({:sessions, env_state.env_id}, :stop)
    send_on_env_stop_event(env_state)
    if not is_nil(from), do: GenServer.reply(from, :ok)
    EnvManagers.terminate_app(self())
  end
end
