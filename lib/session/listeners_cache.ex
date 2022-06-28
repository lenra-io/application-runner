defmodule ApplicationRunner.ListenersCache do
  @moduledoc """
    This module creates a Cache for all the listeners.
    It save the listener props/action using a hash the value (sha256) as key.
    Then we can retrieve the listener (action/props) by giving the key.
  """
  use ApplicationRunner.CacheMapMacro

  alias ApplicationRunner.{
    SessionState,
    SessionSupervisor,
    ListenersCache
  }

  @spec build_listener(SessionState.t(), map()) :: map()
  def build_listener(session_state, listener) do
    case listener do
      %{"action" => action} ->
        props = Map.get(listener, "props", %{})
        listener_key = Crypto.hash({action, props})
        ListenersCache.save_listener(session_state, listener_key, listener)
        listener |> Map.drop(["action", "props"]) |> Map.put("code", listener_key)

      _ ->
        %{}
    end
  end

  @spec save_listener(SessionState.t(), String.t(), map()) :: :ok
  def save_listener(%SessionState{} = session_state, code, listener) do
    pid = SessionSupervisor.fetch_module_pid!(session_state.session_supervisor_pid, __MODULE__)
    put(pid, code, listener)
    :ok
  end

  @spec fetch_listener(SessionState.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def fetch_listener(%SessionState{} = session_state, code) do
    pid = SessionSupervisor.fetch_module_pid!(session_state.session_supervisor_pid, __MODULE__)

    case get(pid, code) do
      nil -> {:error, :no_listener_with_code}
      res -> {:ok, res}
    end
  end
end
