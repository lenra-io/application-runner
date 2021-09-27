defmodule ApplicationRunner.UIValidator do
  @moduledoc """
    Services to validate json with json schema
  """

  alias ApplicationRunner.{JsonSchemata, Storage}

  @type ui :: map()
  @type component :: map()
  @type error_tuple :: {String.t(), String.t()}
  @type build_errors :: list(error_tuple())

  @spec validate_and_build(ui()) :: {:ok, ui()} | {:error, build_errors()}
  def validate_and_build(ui) do
    with {:ok, _} <- validate_with_error("root.schema.json", ui, "#") do
      ui["root"]
      |> validate_and_build_component("#/root")
    end
    |> case do
      {:ok, ui} -> {:ok, %{"root" => ui}}
      error -> error
    end
  end

  @spec validate_and_build_component(component(), String.t()) ::
          {:ok, component()} | {:error, build_errors()}
  def validate_and_build_component(%{"type" => comp_type} = component, prefix_path) do
    with schema_path <- JsonSchemata.get_component_path(comp_type),
         {:ok, %{listeners: listeners, children: children, child: child}} <-
           validate_with_error(schema_path, component, prefix_path),
         {:ok, children_map} <-
           validate_and_build_children_list(component, children, prefix_path),
         {:ok, child_map} <- validate_and_build_child_list(component, child, prefix_path),
         {:ok, listeners_map} <- build_listeners(component, listeners) do
      {:ok,
       component
       |> Map.merge(children_map)
       |> Map.merge(child_map)
       |> Map.merge(listeners_map)}
    end
  end

  def validate_with_error(schema_path, component, prefix_path) do
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
        built_listener = Map.delete(listener, "action") |> Map.delete("props")
        props = Map.get(listener, "props", %{})
        listener_key = Storage.generate_listeners_key(action_code, props)
        Storage.insert(:listeners, listener_key, listener)
        {:ok, Map.merge(built_listener, %{"code" => listener_key})}

      _ ->
        {:ok, %{}}
    end
  end

  @spec validate_and_build_child_list(component(), list(String.t()), String.t()) ::
          {:ok, map()} | {:error, build_errors()}
  def validate_and_build_child_list(component, child_list, prefix_path) do
    Enum.reduce(child_list, {%{}, []}, fn child, {acc, errors} ->
      child_path = "#{prefix_path}/#{child}"

      case Map.get(component, child) do
        nil ->
          {acc, errors}

        child_comp ->
          validate_and_build_component(child_comp, child_path)
          |> handle_built_child(child, {acc, errors})
      end
    end)
    |> case do
      {comp, []} -> {:ok, comp}
      {_, errors} -> {:error, errors}
    end
  end

  defp handle_built_child(built_comp, comp_name, {built, errors}) do
    case built_comp do
      {:ok, built_component} ->
        {Map.merge(built, %{comp_name => built_component}), errors}

      {:error, comp_errors} ->
        {built, comp_errors ++ errors}
    end
  end

  @spec validate_and_build_children_list(component(), list(), String.t()) ::
          {:ok, map()} | {:error, build_errors()}
  def validate_and_build_children_list(component, children_list, prefix_path) do
    Enum.reduce(children_list, {%{}, []}, fn children, {acc, errors} ->
      children_path = "#{prefix_path}/#{children}"

      case validate_and_build_children(component, children, children_path) do
        {:ok, []} ->
          {acc, errors}

        {:ok, built_children} ->
          {Map.merge(acc, %{children => built_children}), errors}

        {:error, children_errors} ->
          {acc, children_errors ++ errors}
      end
    end)
    |> case do
      {comp, []} -> {:ok, comp}
      {_, errors} -> {:error, errors}
    end
  end

  @spec validate_and_build_children(map, String.t(), String.t()) ::
          {:error, list(error_tuple())} | {:ok, list(component())}
  def validate_and_build_children(component, children, prefix_path) do
    case Map.get(component, children) do
      nil ->
        {:ok, []}

      children_comp ->
        build_children_map(children_comp, prefix_path)
    end
  end

  defp build_children_map(children, prefix_path) do
    children
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {child, index}, {acc, errors} ->
      children_path = "#{prefix_path}/#{index}"

      case validate_and_build_component(child, children_path) do
        {:ok, built_component} ->
          {acc ++ [built_component], errors}

        {:error, children_errors} ->
          {acc, errors ++ children_errors}
      end
    end)
    |> case do
      {comp, []} -> {:ok, comp}
      {_, errors} -> {:error, errors}
    end
  end
end
