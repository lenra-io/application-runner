defmodule ApplicationRunner.SessionManager do
  @moduledoc """
    This module is the Session supervisor that handle the SupervisorManager children modules.
  """
  use GenServer

  alias ApplicationRunner.{
    SessionManagers,
    SessionSupervisor,
    SessionState,
    WidgetCache,
    WidgetContext,
    ActionBuilder
  }

  @inactivity_timeout Application.compile_env!(:application_runner, :session_inactivity_timeout)

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    env_id = Keyword.fetch!(opts, :env_id)

    with {:ok, pid} <-
           GenServer.start_link(__MODULE__, opts, name: {:via, :swarm, {:session, session_id}}) do
      Swarm.join(:sessions, pid)
      Swarm.join({:sessions, env_id}, pid)
      {:ok, pid}
    end
  end

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    env_id = Keyword.fetch!(opts, :env_id)

    {:ok, session_supervisor_pid} = SessionSupervisor.start_link(opts)
    # Link the process to kill the manager if the supervisor is killed.
    # The SessionManager should be restarted by the SessionManagers then it will restart the supervisor.
    Process.link(session_supervisor_pid)

    session_state = %SessionState{
      session_id: session_id,
      env_id: env_id,
      session_supervisor_pid: session_supervisor_pid
    }

    {:ok, session_state, @inactivity_timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    SessionManagers.terminate_session(self())
    {:noreply, state}
  end

  @doc """
    return the app-level module.
    This can be used to get module declared in the `SessionSupervisor` (like the cache module for example)
  """
  def fetch_module_pid(session_manager_pid, module_name) when is_pid(session_manager_pid) do
    with {:ok, supervisor_pid} <- fetch_supervisor_pid(session_manager_pid) do
      Supervisor.which_children(supervisor_pid)
      |> Enum.find({:error, :no_such_module}, fn
        {name, _, _, _} -> module_name == name
      end)
      |> case do
        {_, pid, _, _} ->
          {:ok, pid}

        {:error, :no_such_module} ->
          raise "No such Module in SessionSupervisor. This should not happen."
      end
    end
  end

  defp fetch_supervisor_pid(session_manager_pid) when is_pid(session_manager_pid) do
    {:ok, GenServer.call(session_manager_pid, :get_session_supervisor_pid)}
  end

  def get_widget(%SessionState{} = session_state, %WidgetContext{} = widget_context) do
    with {:ok, env_pid} <- SessionManagers.fetch_session_manager_pid(session_state.session_id),
         {:ok, cache_pid} <- fetch_module_pid(env_pid, WidgetCache),
         {:ok, data} <- ActionBuilder.get_data(session_state) do
      WidgetCache.get_widget(cache_pid, widget_context.name, data, widget_context.props)
    end
  end

  def get_ui() do
  end

  @impl
  def handle_call(:get_ui, _from, state) do
  end

  @impl true
  def handle_call(:get_session_supervisor_pid, _from, state) do
    case Map.fetch!(state, :session_supervisor_pid) do
      nil -> raise "No SessionSupervisor. This should not happen."
      res -> {:reply, res, state, @inactivity_timeout}
    end
  end

  @doc """
    This callback is called when the `SessionManagers` is asked to kill this node.
    We cannot call directly `DynamicSupervisor.terminate_child/2` as we could be asking it on the wrong node.
    To prevent this we simply ask the child to call `DynamicSupervisor.terminate_child/2`to ensure that the correct SessionManagers is called.
  """
  @impl true
  def handle_cast(:stop, state) do
    SessionManagers.terminate_session(self())
    {:noreply, state}
  end
end
