defmodule ApplicationRunner.Session.UiServer do
  use GenServer
  use SwarmNamed

  @type widget :: map()
  @type component :: map()
  @type error_tuple :: {String.t(), String.t()}
  @type build_errors :: list(error_tuple())

  alias ApplicationRunner.Environment
  alias ApplicationRunner.Environment.{WidgetServer, WidgetDynSup, WidgetUid}
  alias ApplicationRunner.Session
  alias ApplicationRunner.Ui
  alias ApplicationRunner.AppChannel

  alias ApplicationRunner.JsonSchemata

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: get_full_name(session_id))
  end

  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    with {:ok, ui} <- load_ui(session_id) do
      send_to_channel(session_id, :ui, ui)
      {:ok, %{session_id: session_id, ui: ui}}
    else
      err ->
        send_to_channel(session_id, :error, err)
        {:stop, err}
    end
  end

  def handle_cast(:rebuild, %{session_id: session_id, ui: old_ui} = state) do
    with {:ok, ui} <- load_ui(session_id) do
      send_to_channel(session_id, :patches, JSONDiff.diff(old_ui, ui))
      {:noreply, Map.put(state, :ui, ui)}
    else
      err ->
        send_to_channel(session_id, :error, err)
        {:noreply, state}
    end
  end

  def load_ui(session_id) do
    session_metadata = Session.MetadataAgent.get_metadata(session_id)
    root_widget = Environment.ManifestHandler.get_root_widget(session_metadata.env_id)

    with {:ok, ui_context} <-
           get_and_build_widget(session_metadata, Ui.Context.new(), root_widget) do
      {:ok,
       transform_ui(%{"rootWidget" => widget_id(root_widget), "widgets" => ui_context.widgets_map})}
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

  defp send_to_channel(session_id, atom, stuff) do
    Swarm.publish(AppChannel.get_group(session_id), {:send, atom, stuff})
  end

  @spec get_and_build_widget(Session.Metadata.t(), Ui.Context.t(), WidgetUid.t()) ::
          {:ok, Ui.Context.t()} | {:error, any()}
  defp get_and_build_widget(
         %Session.Metadata{} = session_metadata,
         %Ui.Context{} = ui_context,
         %WidgetUid{} = widget_uid
       ) do
    with {:ok, widget} <- get_widget(session_metadata, widget_uid),
         {:ok, component, new_app_context} <-
           build_component(session_metadata, widget, ui_context, widget_uid) do
      str_widget_id = widget_id(widget_uid)
      {:ok, put_in(new_app_context.widgets_map[str_widget_id], component)}
    end
  end

  @spec get_widget(Session.Metadata.t(), WidgetUid.t()) :: {:ok, map()} | {:error, any()}
  defp get_widget(%Session.Metadata{} = session_metadata, %WidgetUid{} = widget_uid) do
    with {:ok, _} <-
           WidgetDynSup.ensure_child_started(
             session_metadata.env_id,
             session_metadata.session_id,
             session_metadata.function_name,
             widget_uid
           ) do
      widget = WidgetServer.get_widget(session_metadata.env_id, widget_uid)

      {:ok, widget}
    end
  end

  # Build a component.
  # If the component type is "widget" this is considered a Widget and will be handled like one.
  # Everything else will be handled as a simple component.
  @spec build_component(Session.Metadata.t(), widget(), Ui.Context.t(), WidgetUid.t()) ::
          {:ok, component(), UI.Context.t()} | {:error, build_errors()}
  defp build_component(
         session_metadata,
         %{"type" => comp_type} = component,
         ui_context,
         widget_uid
       ) do
    with schema_path <- JsonSchemata.get_component_path(comp_type),
         {:ok, validation_data} <- validate_with_error(schema_path, component, widget_uid) do
      case comp_type do
        "widget" ->
          handle_widget(session_metadata, component, ui_context, widget_uid)

        _ ->
          handle_component(
            session_metadata,
            component,
            ui_context,
            widget_uid,
            validation_data
          )
      end
    end
  end

  # Build a widget means :
  # - getting the name and props, coll and query of the widget
  # - create the ID of the widget with name/data/props
  # - Create a new WidgetContext corresponding to the Widget
  # - Recursively get_and_build_widget.
  @spec handle_widget(Session.Metadata.t(), widget(), Ui.Context.t(), WidgetUid.t()) ::
          {:ok, component(), Ui.Context.t()}
  defp handle_widget(session_metadata, component, ui_context, widget_uid) do
    name = Map.get(component, "name")
    props = Map.get(component, "props")
    coll = Map.get(component, "coll")
    query = Map.get(component, "query", %{}) |> Jason.encode!()

    new_widget_uid = %WidgetUid{
      name: name,
      props: props,
      prefix_path: widget_uid.prefix_path,
      query: query,
      coll: coll
    }

    case get_and_build_widget(session_metadata, ui_context, new_widget_uid) do
      {:ok, new_app_context} ->
        {
          :ok,
          %{"type" => "widget", "id" => widget_id(new_widget_uid), "name" => name},
          new_app_context
        }

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Build a components means to :
  #   - Recursively build all children (list of child) properties
  #   - Recursively build all single child properties
  #   - Build all listeners
  #   - Then merge all children/child context/widget with the current one.
  @spec handle_component(
          Session.Metadata.t(),
          component(),
          Ui.Context.t(),
          WidgetUid.t(),
          map()
        ) ::
          {:ok, component(), Ui.Context.t()} | {:error, build_errors()}
  defp handle_component(
         %Session.Metadata{} = session_metadata,
         component,
         ui_context,
         widget_uid,
         %{listeners: listeners_keys, children: children_keys, child: child_keys}
       ) do
    with {:ok, children_map, merged_children_ui_context} <-
           build_children_list(
             session_metadata,
             component,
             children_keys,
             ui_context,
             widget_uid
           ),
         {:ok, child_map, merged_child_ui_context} <-
           build_child_list(session_metadata, component, child_keys, ui_context, widget_uid),
         {:ok, listeners_map} <-
           build_listeners(session_metadata, component, listeners_keys) do
      new_context = %Ui.Context{
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

  # Validate the component against the corresponding Json Schema.
  # Returns the data needed for the component to build.
  # If there is a validation error, return the `{:error, build_errors}` tuple.
  @spec validate_with_error(String.t(), component(), WidgetUid.t()) ::
          {:error, list} | {:ok, map()}
  defp validate_with_error(schema_path, component, %WidgetUid{prefix_path: prefix_path}) do
    with {:ok, %{schema: schema} = schema_map} <- JsonSchemata.get_schema_map(schema_path),
         :ok <- ExComponentSchema.Validator.validate(schema, component) do
      {:ok, schema_map}
    else
      {:error, errors} ->
        {:error,
         Enum.map(errors, fn
           {message, "#" <> path} -> {message, prefix_path <> path}
         end)}
    end
  end

  # Build all child properties of the `component` from the given `child_list` of child properties.
  # Return {:ok, builded_component, updated_ui_context} in case of success.
  # Return {:error, build_errors} in case of any failure in one child.
  @spec build_child_list(
          Session.Metadata.t(),
          component(),
          list(String.t()),
          Ui.Context.t(),
          WidgetUid.t()
        ) ::
          {:ok, map(), Ui.Context.t()} | {:error, build_errors()}
  defp build_child_list(
         session_metadata,
         component,
         child_list,
         ui_context,
         widget_uid
       ) do
    case reduce_child_list(session_metadata, component, child_list, ui_context, widget_uid) do
      {comp, merged_ui_context, []} -> {:ok, comp, merged_ui_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  defp reduce_child_list(
         session_metadata,
         component,
         child_list,
         ui_context,
         %WidgetUid{prefix_path: prefix_path} = widget_uid
       ) do
    Enum.reduce(
      child_list,
      {%{}, ui_context, []},
      fn child_key, {child_map, ui_context_acc, errors} ->
        case Map.get(component, child_key) do
          nil ->
            {child_map, ui_context_acc, errors}

          child_comp ->
            child_path = "#{prefix_path}/#{child_key}"

            build_comp_and_format(
              session_metadata,
              child_map,
              child_comp,
              child_key,
              errors,
              ui_context_acc,
              ui_context,
              Map.put(widget_uid, :prefix_path, child_path)
            )
        end
      end
    )
  end

  defp build_comp_and_format(
         session_metadata,
         child_map,
         child_comp,
         child_key,
         errors,
         ui_context_acc,
         ui_context,
         widget_uid
       ) do
    case build_component(
           session_metadata,
           child_comp,
           ui_context,
           widget_uid
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

  # Build all children properties of the `component` from the given `children_list` of children properties.
  # Return {:ok, builded_component, updated_ui_context} in case of success.
  # Return {:error, build_errors} in case of any failure in one children list.
  @spec build_children_list(
          Session.Metadata.t(),
          component(),
          list(),
          Ui.Context.t(),
          WidgetUid.t()
        ) ::
          {:ok, map(), Ui.Context.t()} | {:error, build_errors()}
  defp build_children_list(
         session_metadata,
         component,
         children_keys,
         %Ui.Context{} = ui_context,
         %WidgetUid{prefix_path: prefix_path} = widget_uid
       ) do
    Enum.reduce(children_keys, {%{}, ui_context, []}, fn children_key,
                                                         {children_map, app_context_acc, errors} =
                                                           acc ->
      if Map.has_key?(component, children_key) do
        children_path = "#{prefix_path}/#{"children_key"}"

        case build_children(
               session_metadata,
               component,
               children_key,
               ui_context,
               Map.put(widget_uid, :prefix_path, children_path)
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

  @spec build_children(Session.Metadata.t(), map, String.t(), Ui.Context.t(), WidgetUid.t()) ::
          {:error, list(error_tuple())} | {:ok, list(component()), Ui.Context.t()}
  defp build_children(session_metadata, component, children_key, ui_context, widget_uid) do
    case Map.get(component, children_key) do
      nil ->
        {:ok, [], ui_context}

      children ->
        build_children_map(session_metadata, children, ui_context, widget_uid)
    end
  end

  defp build_children_map(
         session_metadata,
         children,
         ui_context,
         %WidgetUid{prefix_path: prefix_path} = widget_uid
       ) do
    children
    |> Enum.with_index()
    |> Parallel.map(fn {child, index} ->
      children_path = "#{prefix_path}/#{index}"

      build_component(
        session_metadata,
        child,
        ui_context,
        Map.put(widget_uid, :prefix_path, children_path)
      )
    end)
    |> Enum.reduce(
      {[], ui_context, []},
      fn builded_child, {built_components, ui_context_acc, errors} ->
        case builded_child do
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

  @spec build_listeners(Session.Metadata.t(), component(), list(String.t())) ::
          {:ok, map()} | {:error, list()}
  defp build_listeners(session_metadata, component, listeners) do
    Enum.reduce(listeners, {:ok, %{}}, fn listener, {:ok, acc} ->
      case build_listener(session_metadata, Map.get(component, listener)) do
        {:ok, %{"code" => _} = built_listener} -> {:ok, Map.put(acc, listener, built_listener)}
        {:ok, %{}} -> {:ok, acc}
      end
    end)
  end

  @spec build_listener(Session.Metadata.t(), map()) :: {:ok, map()}
  defp build_listener(session_metadata, listener) do
    case listener do
      %{"action" => action} ->
        props = Map.get(listener, "props", %{})
        code = Session.ListenersCache.create_code(action, props)
        Session.ListenersCache.save_listener(session_metadata.session_id, code, listener)
        {:ok, listener |> Map.drop(["action", "props"]) |> Map.put("code", code)}

      _ ->
        {:ok, %{}}
    end
  end

  defp widget_id(%WidgetUid{} = widget_uid) do
    Crypto.hash({widget_uid.name, widget_uid.coll, widget_uid.query, widget_uid.props})
  end
end
