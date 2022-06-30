defmodule ApplicationRunner.ListenersCache do
  @moduledoc """
    This module creates a Cache for all the listeners.
    It save the listener props/action using a hash the value (sha256) as key.
    Then we can retrieve the listener (action/props) by giving the key.
  """
  use ApplicationRunner.Cache.Macro

  alias ApplicationRunner.Session.{
    State,
    Supervisor
  }

  @spec save_listener(State.t(), String.t(), map()) :: :ok
  def save_listener(%State{} = session_state, code, listener) do
    pid = Supervisor.fetch_module_pid!(session_state.session_supervisor_pid, __MODULE__)
    put(pid, code, listener)
    :ok
  end

  @spec fetch_listener(State.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def fetch_listener(%State{} = session_state, code) do
    pid = Supervisor.fetch_module_pid!(session_state.session_supervisor_pid, __MODULE__)

    case get(pid, code) do
      nil -> {:error, :no_listener_with_code}
      res -> {:ok, res}
    end
  end
end
