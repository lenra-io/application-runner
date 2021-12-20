defmodule ApplicationRunner.ListenersCache do
  use ApplicationRunner.CacheMapMacro

  alias ApplicationRunner.{SessionState, Storage, WidgetHandler}

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
  def build_listener(_session_state, listener) do
    case listener do
      %{"action" => action_code} ->
        props = Map.get(listener, "props", %{})
        listener_key = Storage.generate_listeners_key(action_code, props)
        Storage.insert(:listeners, listener_key, listener)
        {:ok, listener |> Map.drop(["action", "props"]) |> Map.put("code", listener_key)}

      _ ->
        {:ok, %{}}
    end
  end

  @doc ~S"""
    Return a listener key created with `client_id`, `app_name`, `action_code` and `props`.
    Each key is uniq for the same arguments

    # Examples
      iex> ApplicationRunner.Storage.generate_listeners_key("InitData", %{"toto" => "tata"})
      "InitData:{\"toto\":\"tata\"}"
  """
  defp generate_listeners_key(action_code, props) do
    "#{action_code}:#{Jason.encode!(props)}"
  end
end
