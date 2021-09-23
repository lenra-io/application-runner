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
    %{schema: schema} = JsonSchemata.get_schema_map("root.schema.json")

    with :ok <- ExComponentSchema.Validator.validate(schema, ui) do
      ui["root"]
      |> validate_and_build_component("/root")
    end
  end

  @spec validate_and_build_component(component(), String.t()) ::
          {:ok, component()} | {:error, build_errors()}
  def validate_and_build_component(%{"type" => comp_type} = component, prefix_path) do
    schema_map =
      JsonSchemata.get_component_path(comp_type)
      |> JsonSchemata.get_schema_map()

    comp_path = "#{prefix_path}/#{comp_type}"

    with %{schema: schema, listeners: listeners, children: children, child: child} <- schema_map,
         :ok <- ExComponentSchema.Validator.validate(schema, component),
         {:ok, children_map} <-
           validate_and_build_children_list(component, children, comp_path),
         {:ok, child_map} <- validate_and_build_child_list(component, child, comp_path),
         {:ok, listeners_map} <- build_listeners(component, listeners) do
      {:ok,
       component
       |> Map.merge(children_map)
       |> Map.merge(child_map)
       |> Map.merge(listeners_map)}
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
          |> handle_built_child(child, child_path, {acc, errors})
      end
    end)
    |> case do
      {comp, []} -> {:ok, comp}
      {_, errors} -> {:error, errors}
    end
  end

  defp handle_built_child(built_comp, comp_name, comp_path, {built, errors}) do
    case built_comp do
      {:ok, built_component} ->
        {Map.merge(built, %{comp_name => built_component}), errors}

      {:error, comp_errors} ->
        tmp = Enum.map(comp_errors, &{elem(&1, 0), comp_path})
        {built, errors ++ tmp}
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
          tmp = Enum.map(children_errors, &{elem(&1, 0), children_path})
          {acc, errors ++ tmp}
      end
    end)
    |> case do
      {comp, []} -> {:ok, comp}
      {_, errors} -> {:error, errors}
    end
  end

  def validate_and_build_children(component, children, prefix_path) do
    case Map.get(component, children) do
      nil ->
        {:ok, []}

      children_comp ->
        build_children_map(children_comp, children, prefix_path)
    end
  end

  defp build_children_map(children, children_name, prefix_path) do
    Enum.reduce(children, {[], []}, fn child, {acc, errors} ->
      children_path = "#{prefix_path}/#{children_name}"

      case validate_and_build_component(child, "") do
        {:ok, built_component} ->
          {acc ++ [built_component], errors}

        {:error, children_errors} ->
          tmp = Enum.map(children_errors, &{elem(&1, 0), children_path})
          {acc, errors ++ tmp}
      end
    end)
    |> case do
      {comp, []} -> {:ok, comp}
      {_, errors} -> {:error, errors}
    end
  end
end
