defmodule ApplicationRunner.Environment.Supervisor do
  @moduledoc """
    This module handles the children module of an AppManager.
  """
  use Supervisor

  alias ApplicationRunner.Environment.Managers

  @doc """
    return the app-level module.
    This can be used to get module declared in the `EnvSupervisor` (like the cache module for example)
  """
  @spec fetch_module_pid!(pid() | any(), atom()) :: pid()
  def fetch_module_pid!(env_supervisor_pid, module_name) when is_pid(env_supervisor_pid) do
    Supervisor.which_children(env_supervisor_pid)
    |> Enum.find({:error, :no_such_module}, fn
      {name, _, _, _} -> module_name == name
    end)
    |> case do
      {_, pid, _, _} ->
        pid

      {:error, :no_such_module} ->
        raise "No such Module in EnvSupervisor. This should not happen."
    end
  end

  def fetch_module_pid!(env_id, module_name) do
    with {:ok, env_manager_pid} <- Managers.fetch_env_manager_pid(env_id),
         env_supervisor_pid <- GenServer.call(env_manager_pid, :fetch_env_supervisor_pid!) do
      fetch_module_pid!(env_supervisor_pid, module_name)
    end
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true

  def init(opts) do
    children =
      [
        ApplicationRunner.EventHandler,
        {ApplicationRunner.Environment.Token.Agent, opts}
      ] ++ get_additionnal_modules(opts)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp get_additionnal_modules(opts) do
    case Application.get_env(:application_runner, :additional_env_modules, :none) do
      {module_name, function_name} ->
        apply(module_name, function_name, [opts])

      :none ->
        []
    end
  end
end
