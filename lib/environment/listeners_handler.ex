defmodule ApplicationRunner.ListenersHandler do
  use ApplicationRunner.CacheMapMacro

  alias ApplicationRunner.{SessionState, WidgetHandler, SessionManager, ListenerCache}

  @spec build_listeners(SessionState.t(), WidgetHandler.component(), list(String.t())) ::
          {:ok, map()} | {:error, list()}
  def build_listeners(session_state, component, listeners) do
    Enum.reduce(listeners, {:ok, %{}}, fn listener, {:ok, acc} ->
      case build_listener(session_state, Map.get(component, listener)) do
        {:ok, %{"code" => _} = built_listener} -> {:ok, Map.put(acc, listener, built_listener)}
        {:ok, %{}} -> {:ok, acc}
      end
    end)
  end

  @spec build_listener(SessionState.t(), map()) :: {:ok, map()}
  defp build_listener(session_state, listener) do
    case listener do
      %{"action" => action_code} ->
        props = Map.get(listener, "props", %{})
        listener_key = generate_listeners_key(action_code, props)
        {:ok, pid} = SessionManager.fetch_module_pid(session_state, ListenerCache)
        put(pid, listener_key, listener)
        {:ok, listener |> Map.drop(["action", "props"]) |> Map.put("code", listener_key)}

      _ ->
        {:ok, %{}}
    end
  end

  defp generate_listeners_key(action_code, props) do
    binary = :erlang.term_to_binary(action_code) <> :erlang.term_to_binary(props)
    :crypto.hash(:sha256, binary)
  end
end
