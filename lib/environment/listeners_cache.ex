defmodule ApplicationRunner.ListenersCache do
  use ApplicationRunner.CacheMapMacro
  alias ApplicationRunner.{EnvState, EnvManager, ListenersCache}

  @spec cache_listener(EnvState.t(), String.t(), map()) :: :ok
  def cache_listener(%EnvState{} = env_state, listener_key, listener) do
    {:ok, pid} = EnvManager.fetch_module_pid(env_state, ListenersCache)
    put(pid, listener_key, listener)
    :ok
  end

  def generate_listeners_key(action_code, props) do
    binary = :erlang.term_to_binary(action_code) <> :erlang.term_to_binary(props)

    :crypto.hash(:sha256, binary)
    |> Base.encode64()
  end
end
