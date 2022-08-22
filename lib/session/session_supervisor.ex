defmodule ApplicationRunner.Session.Supervisor do
  @moduledoc """
    This Supervisor is started by the SessionManager.
    It handle all the GenServer needed for the Session to work.
  """
  use Supervisor

  alias ApplicationRunner.Session.Managers

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
    with {:ok, session_manager_pid} <- Managers.fetch_session_manager_pid(session_id),
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
    # This is how the supervisor should look like with mongo update
    # children = [
    #   {ApplicationRunner.Session.Token.Agent, opts}
    #   ApplicationRunner.EventHandler
    #   Event.OnUserFirstJoin
    #   Event.OnSessionStart
    #   UiBuilder
    # ]
    state = Keyword.merge(opts, session_supervisor_pid: self())

    children = [
      # TODO: add module once they done !
      # {ApplicationRunner.Session.Token.Agent, opts}
      ApplicationRunner.EventHandler,
      # Event.OnUserFirstJoin
      # Event.OnSessionStart
      # UiBuilder

      {ApplicationRunner.Session.Manager, state}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
