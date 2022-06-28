defmodule ApplicationRunner.JsonView do
  alias ApplicationRunner.{
    AdapterHandler,
    DataServices,
    SessionState,
    ListenersCache
  }

  @spec get_and_build_ui(SessionState.t(), map(), map()) ::
          {:ok, map()} | {:error, any()}
  def get_and_build_ui(session_state, root_widget, path_params) do
    props = Map.get(root_widget, "props", %{})
    props = Map.put(props, "pathParams", path_params)
    name = Map.get(root_widget, "name")
    query = root_widget |> Map.get("query") |> DataServices.json_parser()

    data =
      if is_nil(query) do
        []
      else
        AdapterHandler.exec_query(session_state, query, path_params)
      end

    with {:ok, widget} <- AdapterHandler.get_widget(session_state, name, data, props) do
      {:ok, transform_listeners(session_state, widget)}
    end
  end

  defp transform_listeners(session_state, %{"type" => "listener", "action" => _} = listener) do
    ListenersCache.build_listener(session_state, listener)
  end

  defp transform_listeners(session_state, json) when is_map(json) do
    json
    |> Enum.map(fn {k, v} -> {k, transform_listeners(session_state, v)} end)
    |> Enum.into(Map.new())
  end

  defp transform_listeners(session_state, json) when is_list(json) do
    Enum.map(json, fn e -> transform_listeners(session_state, e) end)
  end

  defp transform_listeners(_, json) do
    json
  end
end
