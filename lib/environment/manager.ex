defmodule ApplicationRunner.Environments.Manager do
  @moduledoc """
    This module handles one application. This module is the root_widget to deal with children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    ApplicationServices,
    Environments,
    EventHandler
  }

  alias ApplicationRunner.Environments

  @on_env_start_action "onEnvStart"
  @on_env_stop_action "onEnvStop"

  @spec get_manifest(number()) :: map()
  def get_manifest(env_id) do
    with {:ok, pid} <- Environments.Managers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :get_manifest)
    end
  end

  def wait_until_ready(env_id) do
    with {:ok, pid} <- Environments.Managers.fetch_env_manager_pid(env_id) do
      GenServer.call(pid, :wait_until_ready)
    end
  end

  @spec reload_all_ui(number()) :: :ok
  def reload_all_ui(env_id) do
    Swarm.publish({:sessions, env_id}, :data_changed)
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
    state = Keyword.fetch!(opts, :env_state)
    env_id = Keyword.fetch!(opts, :env_id)
    function_name = Map.fetch!(state, :function_name)
    assigns = Map.fetch!(state, :assigns)

    {:ok, env_supervisor_pid} = Environments.Supervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The EnvManager should be restarted by the EnvManagers then it will restart the supervisor.
    Process.link(env_supervisor_pid)

    event_handler_pid =
      Environments.Supervisor.fetch_module_pid!(env_supervisor_pid, EventHandler)

    EventHandler.subscribe(event_handler_pid)

    env_state = %Environments.State{
      env_id: env_id,
      function_name: function_name,
      assigns: assigns,
      env_supervisor_pid: env_supervisor_pid,
      inactivity_timeout:
        Application.get_env(:application_runner, :env_inactivity_timeout, 1000 * 60 * 60),
      ready?: false,
      waiting_from: []
    }

    with {:ok, manifest} <- ApplicationServices.fetch_manifest(env_state),
         env_state <- Map.put(env_state, :manifest, manifest) do
      {:ok, env_state, {:continue, :after_init}}
    else
      {:error, reason} ->
        {:stop, reason}

      err ->
        {:stop, err}
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

  def handle_call(:wait_until_ready, from, env_state) do
    ready? = Map.get(env_state, :ready?)

    if ready? do
      {:reply, :ok, env_state, env_state.inactivity_timeout}
    else
      waiting_from = Map.get(env_state, :waiting_from, [])
      env_state = Map.put(env_state, :waiting_from, [from | waiting_from])
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

  def handle_info({:event_finished, @on_env_start_action, result}, env_state) do
    waiting_from = Map.get(env_state, :waiting_from, [])
    Enum.each(waiting_from, fn from -> GenServer.reply(from, result) end)

    env_state =
      env_state
      |> Map.put(:ready?, true)
      |> Map.put(:waiting_from, [])

    {:noreply, env_state}
  end

  def handle_info({:event_finished, _action, _result}, env_state) do
    {:noreply, env_state}
  end

  defp do_send_event(env_state, action, props, event) do
    event_handler_pid =
      Environments.Supervisor.fetch_module_pid!(env_state.env_supervisor_pid, EventHandler)

    EventHandler.send_event(event_handler_pid, env_state, action, props, event)
  end

  defp send_on_env_start_event(env_state),
    do: do_send_event(env_state, @on_env_start_action, %{}, %{})

  defp send_on_env_stop_event(env_state),
    do: do_send_event(env_state, @on_env_stop_action, %{}, %{})

  defp stop(%Environments.State{} = env_state, from) do
    # Stop all the session node for the given app and stop the app.
    Swarm.multi_call({:sessions, env_state.env_id}, :stop)
    send_on_env_stop_event(env_state)
    if not is_nil(from), do: GenServer.reply(from, :ok)
    Environments.Managers.terminate_app(self())
  end
end
