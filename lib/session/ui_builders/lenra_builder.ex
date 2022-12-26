defmodule ApplicationRunner.Session.UiBuilders.LenraBuilder do
  @moduledoc """
      This module is responsible of building the Lenra view.
  """
  @behaviour ApplicationRunner.Session.UiBuilders.UiBuilderAdapter

  alias ApplicationRunner.{Environment, JsonSchemata, Session, Ui}
  alias ApplicationRunner.Environment.WidgetUid
  alias ApplicationRunner.MongoStorage.MongoUserLink
  alias ApplicationRunner.Session.RouteServer
  alias ApplicationRunner.Session.UiBuilders.UiBuilderAdapter
  alias LenraCommon.Errors

  @type widget :: map()
  @type component :: map()

  def get_routes(env_id) do
    Environment.ManifestHandler.get_lenra_routes(env_id)
  end

  def build_ui(session_metadata, widget_uid) do
    with {:ok, ui_context} <- get_and_build_widget(session_metadata, Ui.Context.new(), widget_uid) do
      {:ok,
       transform_ui(%{
         "rootWidget" => widget_id(widget_uid),
         "widgets" => ui_context.widgets_map
       })}
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

  @spec get_and_build_widget(Session.Metadata.t(), Ui.Context.t(), WidgetUid.t()) ::
          {:ok, Ui.Context.t()} | {:error, UiBuilderAdapter.common_error()}
  defp get_and_build_widget(
         %Session.Metadata{} = session_metadata,
         %Ui.Context{} = ui_context,
         %WidgetUid{} = widget_uid
       ) do
    with {:ok, widget} <- RouteServer.fetch_widget(session_metadata, widget_uid),
         {:ok, component, new_app_context} <-
           build_component(session_metadata, widget, ui_context, widget_uid) do
      str_widget_id = widget_id(widget_uid)
      {:ok, put_in(new_app_context.widgets_map[str_widget_id], component)}
    end
  end

  # Build a component.
  # If the component type is "widget" this is considered a Widget and will be handled like one.
  # Everything else will be handled as a simple component.
  @spec build_component(Session.Metadata.t(), widget(), Ui.Context.t(), WidgetUid.t()) ::
          {:ok, component(), Ui.Context.t()} | {:error, UiBuilderAdapter.common_error()}
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
          {:ok, component(), Ui.Context.t()} | {:error, UiBuilderAdapter.common_error()}
  defp handle_widget(session_metadata, component, ui_context, widget_uid) do
    name = Map.get(component, "name")
    props = Map.get(component, "props")
    coll = Map.get(component, "coll")
    query = Map.get(component, "query", %{})

    with {:ok, new_widget_uid} <-
           RouteServer.create_widget_uid(
             session_metadata,
             name,
             coll,
             query,
             %{},
             props,
             widget_uid.context,
             widget_uid.prefix_path
           ),
         {:ok, new_app_context} <-
           get_and_build_widget(session_metadata, ui_context, new_widget_uid) do
      {
        :ok,
        %{"type" => "widget", "id" => widget_id(new_widget_uid), "name" => name},
        new_app_context
      }
    end
  end

  @spec create_widget_uid(
          Session.Metadata.t(),
          binary(),
          binary() | nil,
          map() | nil,
          map() | nil,
          map(),
          binary()
        ) :: {:ok, WidgetUid.t()} | {:error, LenraCommon.Errors.BusinessError.t()}
  defp create_widget_uid(session_metadata, name, coll, query, props, context, prefix_path) do
    %MongoUserLink{mongo_user_id: mongo_user_id} =
      MongoStorage.get_mongo_user_link!(session_metadata.env_id, session_metadata.user_id)

    params = %{"me" => mongo_user_id}
    query_transformed = Parser.replace_params(query, params)

    with {:ok, query_parsed} <- parse_query(query, params) do
      {:ok,
       %WidgetUid{
         name: name,
         props: props,
         prefix_path: "#{prefix_path}\n@widget:#{name}",
         query_parsed: query_parsed,
         query_transformed: query_transformed,
         coll: coll,
         context: context
       }}
    end
  end

  # The Parser.parse function propagate a wrong warning.
  # Probably due to a bug in the parser grammar.
  # I don't know how to fix this so i just ignore the error...
  # @dialyzer {:nowarn_function, parse_query: 2}
  defp parse_query(query, params) when not is_nil(query) do
    query
    |> Jason.encode!()
    |> Parser.parse(params)
    |> case do
      {:ok, res} ->
        {:ok, MongoStorage.decode_ids(res)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_query(nil, _params) do
    {:ok, nil}
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
          {:ok, component(), Ui.Context.t()} | {:error, UiBuilderAdapter.common_error()}
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
          {:error, UiBuilderAdapter.common_error()} | {:ok, map()}
  defp validate_with_error(schema_path, component, %WidgetUid{prefix_path: prefix_path}) do
    with {:ok, %{schema: schema} = schema_map} <- JsonSchemata.get_schema_map(schema_path),
         :ok <- ExComponentSchema.Validator.validate(schema, component) do
      {:ok, schema_map}
    else
      {:error, errors} ->
        err_message =
          Enum.reduce(errors, "", fn
            {message, "#" <> path}, acc ->
              acc <> "#{message}#{prefix_path <> path}\n\n"
          end)

        {:error, %Errors.BusinessError{message: err_message, reason: :build_errors}}
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
          {:ok, map(), Ui.Context.t()} | {:error, UiBuilderAdapter.common_error()}
  defp build_child_list(
         session_metadata,
         component,
         child_list,
         ui_context,
         widget_uid
       ) do
    case reduce_child_list(session_metadata, component, child_list, ui_context, widget_uid) do
      {:error, error} -> {:error, error}
      {comp, merged_ui_context} -> {:ok, comp, merged_ui_context}
    end
  end

  defp reduce_child_list(
         session_metadata,
         component,
         child_list,
         ui_context,
         %WidgetUid{prefix_path: prefix_path} = widget_uid
       ) do
    Enum.reduce_while(
      child_list,
      {%{}, ui_context},
      fn child_key, {child_map, ui_context_acc} ->
        case Map.get(component, child_key) do
          nil ->
            {:cont, {child_map, ui_context_acc}}

          child_comp ->
            com_type = Map.get(component, "type")
            child_path = "#{prefix_path}/#{com_type}##{child_key}"

            build_comp_and_format(
              session_metadata,
              child_map,
              child_comp,
              child_key,
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
          :cont,
          {
            Map.merge(child_map, %{child_key => built_component}),
            merge_ui_context(ui_context_acc, child_ui_context)
          }
        }

      {:error, comp_error} ->
        {:halt, {:error, comp_error}}
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
          {:ok, map(), Ui.Context.t()} | {:error, UiBuilderAdapter.common_error()}
  defp build_children_list(
         session_metadata,
         component,
         children_keys,
         %Ui.Context{} = ui_context,
         %WidgetUid{prefix_path: prefix_path} = widget_uid
       ) do
    Enum.reduce_while(
      children_keys,
      {%{}, ui_context},
      fn children_key, {children_map, app_context_acc} = acc ->
        if Map.has_key?(component, children_key) do
          comp_type = Map.get(component, "type")
          children_path = "#{prefix_path}/#{comp_type}##{children_key}"

          case build_children(
                 session_metadata,
                 component,
                 children_key,
                 ui_context,
                 Map.put(widget_uid, :prefix_path, children_path)
               ) do
            {:ok, built_children, children_ui_context} ->
              {
                :cont,
                {
                  Map.merge(children_map, %{children_key => built_children}),
                  merge_ui_context(app_context_acc, children_ui_context)
                }
              }

            {:error, child_error} ->
              {:halt, {:error, child_error}}
          end
        else
          {:cont, acc}
        end
      end
    )
    |> case do
      {:error, child_error} -> {:error, child_error}
      {children_map, merged_app_context} -> {:ok, children_map, merged_app_context}
    end
  end

  @spec build_children(Session.Metadata.t(), map, String.t(), Ui.Context.t(), WidgetUid.t()) ::
          {:error, UiBuilderAdapter.common_error()} | {:ok, list(component()), Ui.Context.t()}
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
    |> Enum.reduce_while(
      {[], ui_context},
      fn builded_child, {built_components, ui_context_acc} ->
        case builded_child do
          {:ok, built_component, new_ui_context} ->
            {:cont,
             {built_components ++ [built_component],
              merge_ui_context(ui_context_acc, new_ui_context)}}

          {:error, child_error} ->
            {:halt, {:error, child_error}}
        end
      end
    )
    |> case do
      {:error, error} -> {:error, error}
      {comp, merged_app_context} -> {:ok, comp, merged_app_context}
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
          {:ok, map()} | {:error, UiBuilderAdapter.common_error()}
  defp build_listeners(session_metadata, component, listeners_keys) do
    Enum.reduce_while(
      listeners_keys,
      {:ok, %{}},
      fn listener_key, {:ok, built_listeners} = acc ->
        with {:fetch, {:ok, listener}} <- {:fetch, Map.fetch(component, listener_key)},
             {:build, {:ok, built_listener}} <-
               {:build, RouteServer.build_listener(session_metadata, listener)} do
          {:cont, {:ok, Map.put(built_listeners, listener_key, built_listener)}}
        else
          {:build, err} ->
            {:halt, err}

          {:fetch, :error} ->
            {:cont, acc}
        end
      end
    )
  end

  defp widget_id(%WidgetUid{} = widget_uid) do
    Crypto.hash({widget_uid.name, widget_uid.coll, widget_uid.query_parsed, widget_uid.props})
  end
end
