defmodule ApplicationRunner.ListenersCache do
  use ApplicationRunner.CacheMapMacro
  alias ApplicationRunner.{EnvState, EnvManager, ListenersCache}

  @spec cache_listener(EnvState.t(), String.t(), map()) :: :ok
  def cache_listener(%EnvState{} = env_state, code, listener) do
    with {:ok, pid} <- EnvManager.fetch_module_pid(env_state, ListenersCache) do
      put(pid, code, listener)
      :ok
    end
  end

  def get_listener(%EnvState{} = env_state, code) do
    IO.inspect("get_listener")

    with {:ok, pid} <- EnvManager.fetch_module_pid(env_state, ListenersCache) do
      case get(pid, code) do
        nil -> raise "No listener found with code #{code}"
        res -> res
      end
    end
  end

  def generate_listeners_key(action_code, props) do
    binary = :erlang.term_to_binary(action_code) <> :erlang.term_to_binary(props)

    :crypto.hash(:sha256, binary)
    |> Base.encode64()
  end
end
