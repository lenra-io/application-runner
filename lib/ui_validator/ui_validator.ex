defmodule ApplicationRunner.UIValidator do
  @moduledoc """
    Services to validate json with json schema
  """

  alias ApplicationRunner.{JsonSchemata, Storage, UiContext, WidgetContext, CacheAsync, EnvManager, SessionManagers}

  @type widget_ui :: map()
  @type component :: map()
  @type error_tuple :: {String.t(), String.t()}
  @type build_errors :: list(error_tuple())

  @spec get_and_build_widget(UiContext.t(), WidgetContext.t()) :: {:ok, UiContext.t()} | {:error, any()}
  def get_and_build_widget(%UiContext{} = ui_context, %WidgetContext{} = current_widget) do
    with {:ok, data} <- get_data(ui_context, current_widget),
    {:ok, widget} <- get_widget(ui_context, current_widget, data),
    {:ok, component, new_app_context} <- build_component(widget, ui_context, current_widget) do
      {:ok, put_in(new_app_context.widgets_map[current_widget.widget_id], component)}
    end
  end

  defp get_widget(ui_context, widget_context, data) do
    {:ok, session_pid} = SessionManagers.fetch_session_manager_pid(ui_context.session_id)

    cache_pid = EnvManager.fetch_module_pid(env_pid, "CacheAsync")

    CacheAsync.call_function(ApplicationRunner.ActionBuilder, "get_widget", [ui_context, widget_context, data])
    ApplicationRunner.ActionBuilder.get_widget(ui_context, widget_context, data)
  end

  defp get_data(_app, _widget) do
    {:ok, %{"user" => %{"id" => 1, "page" => "home_pages", "pseudo" => "test_user", "name" => "Test User"}}}
  end

  @spec build_component(widget_ui(), UiContext.t(), WidgetContext.t()) :: {:ok, component(), UiContext.t()} | {:error, build_errors()}
  def build_component(%{"type" => "widget" = comp_type} = component, ui_context, widget_context) do
    with schema_path <- JsonSchemata.get_component_path(comp_type),
         {:ok, _} <-
           validate_with_error(schema_path, component, widget_context) do
            uuid = UUID.uuid1()
            new_widget_context = %WidgetContext{
              widget_id: uuid,
              widget_name: component["name"],
              data_query: component["query"],
              props: component["props"],
              prefix_path: widget_context.prefix_path}
              {:ok, new_app_context} = get_and_build_widget(ui_context, new_widget_context)
              {:ok, %{"type" => "widget", "id" => uuid, "name" => component["name"]}, new_app_context}
    end
  end

  def build_component(%{"type" => comp_type} = component, ui_context, widget_context) do
    with schema_path <- JsonSchemata.get_component_path(comp_type),
         {:ok, %{listeners: listeners_keys, children: children_keys, child: child_keys}} <-
           validate_with_error(schema_path, component, widget_context),
         {:ok, children_map, merged_children_app_context} <-
           build_children_list(component, children_keys, ui_context, widget_context),
         {:ok, child_map, merged_child_app_context} <-
           build_child_list(component, child_keys, ui_context, widget_context),
         {:ok, listeners_map} <- build_listeners(component, listeners_keys) do

      {:ok,
       component
       |> Map.merge(children_map)
       |> Map.merge(child_map)
       |> Map.merge(listeners_map),
       Map.merge(merged_child_app_context, merged_children_app_context)
      }
    end
  end

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

  @spec build_listeners(component(), list(String.t())) :: {:ok, map()} | {:error, list()}
  def build_listeners(component, listeners) do
    Enum.reduce(listeners, {:ok, %{}}, fn listener, {:ok, acc} ->
      case build_listener(Map.get(component, listener)) do
        {:ok, %{"code" => _} = built_listener} -> {:ok, Map.put(acc, listener, built_listener)}
        {:ok, %{}} -> {:ok, acc}
      end
    end)
  end

  @spec build_listener(map()) :: {:ok, map()}
  def build_listener(listener) do
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

  @spec build_child_list(component(), list(String.t()), UiContext.t(), WidgetContext.t()) ::
          {:ok, map(), UiContext.t()} | {:error, build_errors()}
  def build_child_list(component, child_list, ui_context, %WidgetContext{prefix_path: prefix_path} = widget_context) do
    Enum.reduce(child_list, {%{}, ui_context, []}, fn child_key, {child_map, app_context_acc, errors} ->
      child_path = "#{prefix_path || ""}/#{child_key}"

      case Map.get(component, child_key) do
        nil ->
          {child_map, errors}

        child_comp ->
          build_component(child_comp, ui_context, Map.put(widget_context, :prefix_path, child_path))

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

  @spec build_children_list(component(), list(), UiContext.t(), WidgetContext.t()) ::
          {:ok, map(), UiContext.t()} | {:error, build_errors()}
  def build_children_list(component, children_keys, %UiContext{} = ui_context, %WidgetContext{prefix_path: prefix_path} = widget_context) do

    Enum.reduce(children_keys, {%{}, ui_context, []}, fn children_key, {children_map, app_context_acc, errors} ->
      children_path = "#{prefix_path || ""}/#{children_key}"

      case build_children(component, children_key, ui_context, Map.put(widget_context, :prefix_path, children_path)) do
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

  @spec build_children(map, String.t(), UiContext.t(), WidgetContext.t()) ::
          {:error, list(error_tuple())} | {:ok, list(component()), UiContext.t()}
  def build_children(component, children_key, ui_context, widget_context) do
    case Map.get(component, children_key) do
      nil ->
        {:ok, []}

      children ->

        build_children_map(children, ui_context, widget_context)
    end
  end

  defp build_children_map(children, ui_context, %WidgetContext{prefix_path: prefix_path} = widget_context) do
    children
    |> Enum.with_index()
    |> Enum.reduce({[], ui_context, []}, fn {child, index}, {built_components, app_context_acc, errors} ->
      children_path = "#{prefix_path || ""}/#{index}"

      case build_component(child, ui_context, Map.put(widget_context, :prefix_path, children_path)) do
        {:ok, built_component, new_app_context} ->
          {built_components ++ [built_component], merge_app_context(app_context_acc, new_app_context), errors}

        {:error, children_errors} ->
          {built_components, app_context_acc, errors ++ children_errors}
      end
    end)
    |> case do
      {comp, merged_app_context , []} -> {:ok, comp, merged_app_context}
      {_, _, errors} -> {:error, errors}
    end
  end

  defp merge_app_context(app_context1, app_context2) do
    Map.put(app_context1, :widgets_map, Map.merge(app_context1.widgets_map, app_context2.widgets_map))
  end
end
