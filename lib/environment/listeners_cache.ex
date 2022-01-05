defmodule ApplicationRunner.ListenersCache do
  @moduledoc """
    This module create a Cache for all the listeners.
    It save the listener by creating a hash of the action and the props as the key.
    Then we can retreive the listener (action/props) by giving the key.
  """
  use ApplicationRunner.CacheMapMacro

  alias ApplicationRunner.{
    EnvManager,
    EnvState
  }

  @spec save_listener(EnvState.t(), String.t(), map()) :: :ok
  def save_listener(%EnvState{} = env_state, code, listener) do
    pid = EnvManager.fetch_module_pid!(env_state, __MODULE__)
    put(pid, code, listener)
    :ok
  end

  @spec get_listener(EnvState.t(), String.t()) :: map()
  def get_listener(%EnvState{} = env_state, code) do
    pid = EnvManager.fetch_module_pid!(env_state, __MODULE__)

    case get(pid, code) do
      nil -> raise "No listener found with code #{code}"
      res -> res
    end
  end

  @spec generate_listeners_key(String.t(), map()) :: String.t()
  def generate_listeners_key(action_code, props) do
    binary = :erlang.term_to_binary(action_code) <> :erlang.term_to_binary(props)

    :crypto.hash(:sha256, binary)
    |> Base.encode64()
  end
end
