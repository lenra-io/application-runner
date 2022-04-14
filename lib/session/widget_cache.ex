defmodule ApplicationRunner.WidgetCache do
  @moduledoc """
    This module handles the recursive widget building.
    It is called by the SessionManager and calls ListenerCache to cache the listeners.

    This module caches every call to the get_and_build_widget.
    This means that every widget with the same name/data/props is get/build only once.
  """
  use ApplicationRunner.CacheAsyncMacro

  alias ApplicationRunner.{
    AdapterHandler,
    AST,
    JsonSchemata,
    ListenersCache,
    SessionSupervisor,
    SessionState,
    UiContext,
    WidgetContext
  }

  @type widget_ui :: map()
  @type component :: map()
  @type error_tuple :: {String.t(), String.t()}
  @type build_errors :: list(error_tuple())

  @spec clear_cache(SessionState.t()) :: :ok
  def clear_cache(%SessionState{} = session_state) do
    pid = SessionSupervisor.fetch_module_pid!(session_state.session_supervisor_pid, __MODULE__)

    clear(pid)
  end

  @doc """
    Call the Adapter to get the Widget corresponding to the given the `WidgetContext`
  """
  @spec get_widget(SessionState.t(), WidgetContext.t()) :: {:ok, map()} | {:error, any()}
  def get_widget(%SessionState{} = session_state, %WidgetContext{} = current_widget) do
    AdapterHandler.get_widget(
      session_state,
      current_widget.name,
      current_widget.data,
      current_widget.props
    )
  end

  @doc """
    Call the `get_and_build_widget_cached/3` function and cache the result.
    All subsequent call of this function with the same arguments will return the same old cached result.
  """
  @spec get_and_build_widget(SessionState.t(), UiContext.t(), WidgetContext.t()) ::
          {:ok, UiContext.t()} | {:error, any()}
  def get_and_build_widget(
        %SessionState{} = session_state,
        %UiContext{} = ui_context,
        %WidgetContext{} = current_widget
      ) do
    pid = SessionSupervisor.fetch_module_pid!(session_state.session_supervisor_pid, __MODULE__)

    call_function(pid, __MODULE__, :get_and_build_widget_cached, [
      session_state,
      ui_context,
      current_widget
    ])
  end

  @doc """
    Get the widget corresponding to the `WidgetContext` then build it.
    The build phase will transform the listeners and get_and_build all child widgets.
  """
  @spec get_and_build_widget_cached(
          ApplicationRunner.SessionState.t(),
          ApplicationRunner.UiContext.t(),
          ApplicationRunner.WidgetContext.t()
        ) :: {:error, build_errors()} | {:ok, map()}
  def get_and_build_widget_cached(
        %SessionState{} = session_state,
        %UiContext{} = ui_context,
        %WidgetContext{} = current_widget
      ) do
    with {:ok, widget} <- get_widget(session_state, current_widget),
         {:ok, component, new_app_context} <-
           build_component(session_state, widget, ui_context, current_widget) do
      {:ok, put_in(new_app_context.widgets_map[current_widget.id], component)}
    end
  end

  @doc """
    Build a component.
    If the component type is "widget" this is considered a Widget and will be handled like one.
    Everything else will be handled as a simple component.
  """
  @spec build_component(SessionState.t(), widget_ui(), UiContext.t(), WidgetContext.t()) ::
          {:ok, component(), UiContext.t()} | {:error, build_errors()}
  def build_component(
        session_state,
        %{"type" => comp_type} = component,
        ui_context,
        widget_context
      ) do
    with schema_path <- JsonSchemata.get_component_path(comp_type),
         {:ok, validation_data} <- validate_with_error(schema_path, component, widget_context) do
      case comp_type do
        "widget" ->
          handle_widget(session_state, component, ui_context, widget_context)

        _ ->
          handle_component(session_state, component, ui_context, widget_context, validation_data)
      end
    end
  end

  @doc """
    Build a widget means :
    - getting the name and props of the widget
    - create the ID of the widget with name/data/props
    - Create a new WidgetContext corresponding to the Widget
    - Recursively get_and_build_widget.
  """
  @spec handle_widget(SessionState.t(), widget_ui(), UiContext.t(), WidgetContext.t()) ::
          {:ok, component(), UiContext.t()}
  def handle_widget(session_state, component, ui_context, widget_context) do
    name = Map.get(component, "name")
    props = Map.get(component, "props")

    query = component |> Map.get("query") |> AST.Parser.from_json()

    data = AdapterHandler.exec_query(session_state, query)

    id = generate_widget_id(name, query, props)

    new_widget_context = %WidgetContext{
      id: id,
      name: name,
      data: data,
      props: props,
      prefix_path: widget_context.prefix_path
    }

    case get_and_build_widget(session_state, ui_context, new_widget_context) do
      {:ok, new_app_context} ->
        {:ok, %{"type" => "widget", "id" => id, "name" => name}, new_app_context}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
    Build a components means to :
      - Recursively build all children (list of child) properties
      - Recursively build all single child properties
      - Build all listeners
      - Then merge all children/child context/widget with the current one.
  """
  @spec handle_component(SessionState.t(), component(), UiContext.t(), WidgetContext.t(), map()) ::
          {:ok, component(), UiContext.t()} | {:error, build_errors()}
  def handle_component(
        %SessionState{} = session_state,
        component,
        ui_context,
        widget_context,
        %{listeners: listeners_keys, children: children_keys, child: child_keys}
      ) do
    with {:ok, children_map, merged_children_ui_context} <-
           build_children_list(
             session_state,
             component,
             children_keys,
             ui_context,
             widget_context
           ),
         {:ok, child_map, merged_child_ui_context} <-
           build_child_list(session_state, component, child_keys, ui_context, widget_context),
         {:ok, listeners_map} <-
           build_listeners(session_state, component, listeners_keys) do
      new_context = %UiContext{
        widgets_map:
          Map.merge(merged_child_ui_context.widgets_map, merged_children_ui_context.widgets_map),
        listeners_map:
          Map.merge(
            merged_child_ui_context.listeners_map,
            merged_children_ui_context.listeners_map
          )
      }

      {:ok,
       component
       |> Map.merge(children_map)
       |> Map.merge(child_map)
       |> Map.merge(listeners_map), new_context}
    end
  end

  @doc """
    Validate the component against the corresponding Json Schema.
    Returns the data needed for the component to build.
    If there is a validation error, return the `{:error, build_errors}` tuple.
  """
  @spec validate_with_error(String.t(), component(), WidgetContext.t()) ::
          {:error, list} | {:ok, map()}
  def validate_with_error(schema_path, component, %WidgetContext{prefix_path: prefix_path}) do
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

  @doc """
    Build all child properties of the `component` from the given `child_list` of child properties.
    Return {:ok, builded_component, updated_ui_context} in case of success.
    Return {:error, build_errors} in case of any failure in one child.
  """
  @spec build_child_list(
          SessionState.t(),
          component(),
          list(String.t()),
          UiContext.t(),
          WidgetContext.t()
        ) ::
          {:ok, map(), UiContext.t()} | {:error, build_errors()}
  def build_child_list(
        session_state,
        component,
        child_list,
        ui_context,
        widget_context
      ) do
    case reduce_child_list(session_state, component, child_list, ui_context, widget_context) do
      {comp, merged_ui_context, []} -> {:ok, comp, merged_ui_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  defp reduce_child_list(
         session_state,
         component,
         child_list,
         ui_context,
         %WidgetContext{prefix_path: prefix_path} = widget_context
       ) do
    Enum.reduce(
      child_list,
      {%{}, ui_context, []},
      fn child_key, {child_map, ui_context_acc, errors} ->
        case Map.get(component, child_key) do
          nil ->
            {child_map, ui_context_acc, errors}

          child_comp ->
            child_path = "#{prefix_path || ""}/#{child_key}"

            build_comp_and_format(
              session_state,
              child_map,
              child_comp,
              child_key,
              errors,
              ui_context_acc,
              ui_context,
              Map.put(widget_context, :prefix_path, child_path)
            )
        end
      end
    )
  end

  defp build_comp_and_format(
         session_state,
         child_map,
         child_comp,
         child_key,
         errors,
         ui_context_acc,
         ui_context,
         widget_context
       ) do
    case build_component(
           session_state,
           child_comp,
           ui_context,
           widget_context
         ) do
      {:ok, built_component, child_ui_context} ->
        {
          Map.merge(child_map, %{child_key => built_component}),
          merge_ui_context(ui_context_acc, child_ui_context),
          errors
        }

      {:error, comp_errors} ->
        {child_map, ui_context_acc, comp_errors ++ errors}
    end
  end

  @doc """
    Build all children properties of the `component` from the given `children_list` of children properties.
    Return {:ok, builded_component, updated_ui_context} in case of success.
    Return {:error, build_errors} in case of any failure in one children list.
  """
  @spec build_children_list(
          SessionState.t(),
          component(),
          list(),
          UiContext.t(),
          WidgetContext.t()
        ) ::
          {:ok, map(), UiContext.t()} | {:error, build_errors()}
  def build_children_list(
        session_state,
        component,
        children_keys,
        %UiContext{} = ui_context,
        %WidgetContext{prefix_path: prefix_path} = widget_context
      ) do
    Enum.reduce(children_keys, {%{}, ui_context, []}, fn children_key,
                                                         {children_map, app_context_acc, errors} =
                                                           acc ->
      if Map.has_key?(component, children_key) do
        children_path = "#{prefix_path || ""}/#{children_key}"

        case build_children(
               session_state,
               component,
               children_key,
               ui_context,
               Map.put(widget_context, :prefix_path, children_path)
             ) do
          {:ok, built_children, children_ui_context} ->
            {
              Map.merge(children_map, %{children_key => built_children}),
              merge_ui_context(app_context_acc, children_ui_context),
              errors
            }

          {:error, children_errors} ->
            {%{}, ui_context, children_errors ++ errors}
        end
      else
        acc
      end
    end)
    |> case do
      {children_map, merged_app_context, []} -> {:ok, children_map, merged_app_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  @doc """
    This will build a child list (children).
  """
  @spec build_children(SessionState.t(), map, String.t(), UiContext.t(), WidgetContext.t()) ::
          {:error, list(error_tuple())} | {:ok, list(component()), UiContext.t()}
  def build_children(session_state, component, children_key, ui_context, widget_context) do
    case Map.get(component, children_key) do
      nil ->
        {:ok, [], ui_context}

      children ->
        build_children_map(session_state, children, ui_context, widget_context)
    end
  end

  defp build_children_map(
         session_state,
         children,
         ui_context,
         %WidgetContext{prefix_path: prefix_path} = widget_context
       ) do
    children
    |> Enum.with_index()
    |> Enum.reduce(
      {[], ui_context, []},
      fn {child, index}, {built_components, ui_context_acc, errors} ->
        children_path = "#{prefix_path}/#{index}"

        case build_component(
               session_state,
               child,
               ui_context,
               Map.put(widget_context, :prefix_path, children_path)
             ) do
          {:ok, built_component, new_ui_context} ->
            {built_components ++ [built_component],
             merge_ui_context(ui_context_acc, new_ui_context), errors}

          {:error, children_errors} ->
            {built_components, ui_context_acc, errors ++ children_errors}
        end
      end
    )
    |> case do
      {comp, merged_app_context, []} -> {:ok, comp, merged_app_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  defp merge_ui_context(ui_context1, ui_context2) do
    Map.put(
      ui_context1,
      :widgets_map,
      Map.merge(ui_context1.widgets_map, ui_context2.widgets_map)
    )
  end

  @spec build_listeners(SessionState.t(), component(), list(String.t())) ::
          {:ok, map()} | {:error, list()}
  defp build_listeners(session_state, component, listeners) do
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
        listener_key = ListenersCache.generate_listeners_key(action_code, props)
        ListenersCache.save_listener(session_state, listener_key, listener)
        {:ok, listener |> Map.drop(["action", "props"]) |> Map.put("code", listener_key)}

      _ ->
        {:ok, %{}}
    end
  end

  def generate_widget_id(name, query, props) do
    :crypto.hash(:sha256, :erlang.term_to_binary({name, query, props}))
    |> Base.encode64()
  end
end
