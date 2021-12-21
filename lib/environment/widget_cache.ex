defmodule ApplicationRunner.WidgetCache do
  use ApplicationRunner.CacheAsyncMacro

  alias ApplicationRunner.{
    JsonSchemata,
    EnvState,
    EnvManager,
    UiContext,
    WidgetContext,
    ListenersCache,
    WidgetCache,
    AdapterHandler,
    WidgetCache
  }

  @type widget_ui :: map()
  @type component :: map()
  @type error_tuple :: {String.t(), String.t()}
  @type build_errors :: list(error_tuple())

  @spec get_widget(WidgetContext.t()) :: {:ok, map()} | {:error, any()}
  def get_widget(%WidgetContext{} = current_widget) do
    AdapterHandler.get_widget(current_widget.name, current_widget.data, current_widget.props)
  end

  @spec get_and_build_widget(EnvState.t(), UiContext.t(), WidgetContext.t()) ::
          {:ok, UiContext.t()} | {:error, any()}

  def get_and_build_widget(
        %EnvState{} = env_state,
        %UiContext{} = ui_context,
        %WidgetContext{} = current_widget
      ) do
    with {:ok, pid} <- EnvManager.fetch_module_pid(env_state, WidgetCache) do
      call_function(pid, WidgetCache, :get_and_build_widget_cached, [
        env_state,
        ui_context,
        current_widget
      ])
    end
  end

  def get_and_build_widget_cached(
        %EnvState{} = env_state,
        %UiContext{} = ui_context,
        %WidgetContext{} = current_widget
      ) do
    with {:ok, widget} <- WidgetCache.get_widget(current_widget),
         {:ok, component, new_app_context} <-
           build_component(env_state, widget, ui_context, current_widget) do
      {:ok, put_in(new_app_context.widgets_map[current_widget.id], component)}
    end
  end

  @spec build_component(EnvState.t(), widget_ui(), UiContext.t(), WidgetContext.t()) ::
          {:ok, component(), UiContext.t()} | {:error, build_errors()}
  defp build_component(
         env_state,
         %{"type" => comp_type} = component,
         ui_context,
         widget_context
       ) do
    with schema_path <- JsonSchemata.get_component_path(comp_type),
         {:ok, validation_data} <- validate_with_error(schema_path, component, widget_context) do
      case comp_type do
        "widget" ->
          handle_widget(env_state, component, ui_context, widget_context)

        _ ->
          handle_component(env_state, component, ui_context, widget_context, validation_data)
      end
    end
  end

  defp handle_widget(env_state, component, ui_context, widget_context) do
    name = Map.get(component, "name")
    # query = Map.get(component, "query")
    props = Map.get(component, "props")
    id = WidgetCache.generate_widget_id(name, widget_context.data, props)

    new_widget_context = %WidgetContext{
      id: id,
      name: name,
      data: widget_context.data,
      props: props,
      prefix_path: widget_context.prefix_path
    }

    {:ok, new_app_context} = get_and_build_widget(env_state, ui_context, new_widget_context)
    {:ok, %{"type" => "widget", "id" => id, "name" => name}, new_app_context}
  end

  defp handle_component(
         %EnvState{} = env_state,
         component,
         ui_context,
         widget_context,
         %{listeners: listeners_keys, children: children_keys, child: child_keys}
       ) do
    with {:ok, children_map, merged_children_app_context} <-
           build_children_list(
             env_state,
             component,
             children_keys,
             ui_context,
             widget_context
           ),
         {:ok, child_map, merged_child_app_context} <-
           build_child_list(env_state, component, child_keys, ui_context, widget_context),
         {:ok, listeners_map} <-
           build_listeners(env_state, component, listeners_keys) do
      {:ok,
       component
       |> Map.merge(children_map)
       |> Map.merge(child_map)
       |> Map.merge(listeners_map),
       Map.merge(merged_child_app_context, merged_children_app_context)}
    end
  end

  defp validate_with_error(schema_path, component, %WidgetContext{prefix_path: prefix_path}) do
    with {:ok, %{schema: schema} = schema_map} <- JsonSchemata.get_schema_map(schema_path),
         :ok <- ExComponentSchema.Validator.validate(schema, component) do
      {:ok, schema_map}
    else
      {:error, errors} ->
        {:error,
         Enum.map(errors, fn
           {message, "#" <> path} -> {message, (prefix_path || "") <> path}
         end)}
    end
  end

  @spec build_child_list(
          EnvState.t(),
          component(),
          list(String.t()),
          UiContext.t(),
          WidgetContext.t()
        ) ::
          {:ok, map(), UiContext.t()} | {:error, build_errors()}
  defp build_child_list(
         env_state,
         component,
         child_list,
         ui_context,
         %WidgetContext{prefix_path: prefix_path} = widget_context
       ) do
    Enum.reduce(child_list, {%{}, ui_context, []}, fn child_key,
                                                      {child_map, app_context_acc, errors} ->
      child_path = "#{prefix_path || ""}/#{child_key}"

      case Map.get(component, child_key) do
        nil ->
          {child_map, errors}

        child_comp ->
          build_component(
            env_state,
            child_comp,
            ui_context,
            Map.put(widget_context, :prefix_path, child_path)
          )
          |> case do
            {:ok, built_component, child_app_context} ->
              {
                Map.merge(child_map, %{child_key => built_component}),
                merge_app_context(app_context_acc, child_app_context),
                errors
              }

            {:error, comp_errors} ->
              {child_map, comp_errors ++ errors}
          end
      end
    end)
    |> case do
      {comp, merged_app_context, []} -> {:ok, comp, merged_app_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  @spec build_children_list(
          EnvState.t(),
          component(),
          list(),
          UiContext.t(),
          WidgetContext.t()
        ) ::
          {:ok, map(), UiContext.t()} | {:error, build_errors()}
  defp build_children_list(
         env_state,
         component,
         children_keys,
         %UiContext{} = ui_context,
         %WidgetContext{prefix_path: prefix_path} = widget_context
       ) do
    Enum.reduce(children_keys, {%{}, ui_context, []}, fn children_key,
                                                         {children_map, app_context_acc, errors} ->
      children_path = "#{prefix_path || ""}/#{children_key}"

      case build_children(
             env_state,
             component,
             children_key,
             ui_context,
             Map.put(widget_context, :prefix_path, children_path)
           ) do
        {:ok, built_children, children_app_context} ->
          {
            Map.merge(children_map, %{children_key => built_children}),
            merge_app_context(app_context_acc, children_app_context),
            errors
          }

        {:error, children_errors} ->
          {%{}, ui_context, children_errors ++ errors}
      end
    end)
    |> case do
      {children_map, merged_app_context, []} -> {:ok, children_map, merged_app_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  @spec build_children(EnvState.t(), map, String.t(), UiContext.t(), WidgetContext.t()) ::
          {:error, list(error_tuple())} | {:ok, list(component()), UiContext.t()}
  defp build_children(env_state, component, children_key, ui_context, widget_context) do
    case Map.get(component, children_key) do
      nil ->
        {:ok, []}

      children ->
        build_children_map(env_state, children, ui_context, widget_context)
    end
  end

  defp build_children_map(
         env_state,
         children,
         ui_context,
         %WidgetContext{prefix_path: prefix_path} = widget_context
       ) do
    children
    |> Enum.with_index()
    |> Enum.reduce(
      {[], ui_context, []},
      fn {child, index}, {built_components, app_context_acc, errors} ->
        children_path = "#{prefix_path}/#{index}"

        case build_component(
               env_state,
               child,
               ui_context,
               Map.put(widget_context, :prefix_path, children_path)
             ) do
          {:ok, built_component, new_app_context} ->
            {built_components ++ [built_component],
             merge_app_context(app_context_acc, new_app_context), errors}

          {:error, children_errors} ->
            {built_components, app_context_acc, errors ++ children_errors}
        end
      end
    )
    |> case do
      {comp, merged_app_context, []} -> {:ok, comp, merged_app_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  defp merge_app_context(app_context1, app_context2) do
    Map.put(
      app_context1,
      :widgets_map,
      Map.merge(app_context1.widgets_map, app_context2.widgets_map)
    )
  end

  @spec build_listeners(EnvState.t(), WidgetHandler.component(), list(String.t())) ::
          {:ok, map()} | {:error, list()}
  defp build_listeners(env_state, component, listeners) do
    Enum.reduce(listeners, {:ok, %{}}, fn listener, {:ok, acc} ->
      case build_listener(env_state, Map.get(component, listener)) do
        {:ok, %{"code" => _} = built_listener} -> {:ok, Map.put(acc, listener, built_listener)}
        {:ok, %{}} -> {:ok, acc}
      end
    end)
  end

  @spec build_listener(EnvState.t(), map()) :: {:ok, map()}
  defp build_listener(env_state, listener) do
    case listener do
      %{"action" => action_code} ->
        props = Map.get(listener, "props", %{})
        listener_key = ListenersCache.generate_listeners_key(action_code, props)
        ListenersCache.cache_listener(env_state, listener_key, listener)
        {:ok, listener |> Map.drop(["action", "props"]) |> Map.put("code", listener_key)}

      _ ->
        {:ok, %{}}
    end
  end

  def generate_widget_id(name, data, props) do
    :crypto.hash(:sha256, :erlang.term_to_binary({name, data, props}))
    |> Base.encode64()
  end
end