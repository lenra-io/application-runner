defmodule ApplicationRunner.LenraView do
  alias ApplicationRunner.{
    UiContext,
    WidgetContext,
    WidgetCache,
    AdapterHandler,
    DataServices,
    SessionState
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

    id = WidgetCache.generate_widget_id(name, data, props)

    WidgetCache.get_and_build_widget(
      session_state,
      %UiContext{
        widgets_map: %{},
        listeners_map: %{}
      },
      %WidgetContext{
        id: id,
        name: name,
        prefix_path: "",
        data: data,
        props: props
      }
    )
    |> case do
      {:ok, ui_context} ->
        ui = %{"rootWidget" => id, "widgets" => ui_context.widgets_map}
        {:ok, transform_ui(ui)}

      {:error, reason} when is_atom(reason) ->
        {:error, reason}

      {:error, ui_error_list} when is_list(ui_error_list) ->
        {:error, :invalid_ui, ui_error_list}
    end
  end

  defp transform_ui(%{"rootWidget" => root_widget, "widgets" => widgets}) do
    transform(%{"root" => Map.fetch!(widgets, root_widget)}, widgets)
  end

  defp transform(%{"type" => "widget", "id" => id}, widgets) do
    transform(Map.fetch!(widgets, id), widgets)
  end

  defp transform(widget, widgets) when is_map(widget) do
    Enum.map(widget, fn
      {k, v} -> {k, transform(v, widgets)}
    end)
    |> Map.new()
  end

  defp transform(widget, widgets) when is_list(widget) do
    Enum.map(widget, &transform(&1, widgets))
  end

  defp transform(widget, _widgets) do
    widget
  end
end
