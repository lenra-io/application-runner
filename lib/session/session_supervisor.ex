defmodule ApplicationRunner.SessionSupervisor do
  @moduledoc """
    This Supervisor is started by the SessionManager.
    It handle all the GenServer needed for the Session to work.
  """
  use Supervisor

  alias ApplicationRunner.SessionManagers

  @doc """
    return the app-level module.
    This can be used to get module declared in the `SessionSupervisor` (like the cache module for example)
  """
  @spec fetch_module_pid!(pid() | any(), atom()) :: pid()
  def fetch_module_pid!(session_supervisor_pid, module_name)
      when is_pid(session_supervisor_pid) do
    Supervisor.which_children(session_supervisor_pid)
    |> Enum.find({:error, :no_such_module}, fn
      {name, _, _, _} -> module_name == name
    end)
    |> case do
      {_, pid, _, _} ->
        pid

      {:error, :no_such_module} ->
        raise "No such Module in SessionSupervisor. This should not happen."
    end
  end

  def fetch_module_pid!(session_id, module_name) do
    with {:ok, session_manager_pid} <- SessionManagers.fetch_session_manager_pid(session_id),
         session_supervisor_pid <-
           GenServer.call(session_manager_pid, :fetch_session_supervisor_pid!) do
      fetch_module_pid!(session_supervisor_pid, module_name)
    end
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    children =
      [
        ApplicationRunner.UiCache,
        ApplicationRunner.WidgetCache,
        ApplicationRunner.EventHandler,
        ApplicationRunner.ListenersCache
      ] ++ get_additionnal_modules(opts)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp get_additionnal_modules(opts) do
    case Application.get_env(:application_runner, :additional_session_modules, :none) do
      {module_name, function_name} ->
        apply(module_name, function_name, [opts])

      :none ->
        []
    end
  end
end
