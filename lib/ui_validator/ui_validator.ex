defmodule ApplicationRunner.UIValidator do
  @moduledoc """
    Services to validate json with json schema
  """

  alias ApplicationRunner.{JsonSchemata, Storage}

  @type ui :: map()
  @type component :: map()
  @type error_tuple :: {String.t(), String.t()}
  @type build_errors :: list(error_tuple())

  # %{
  #   "type" => "test",
  #   "leftColumn" => [
  #     %{
  #       "type" => "text"
  #     },
  #     %{
  #       "type" => "button"
  #     }
  #   ],
  #   "rightColumn" => [
  #     %{"type" => "button"}
  #   ],
  #   "leftButton" => %{
  #     "type" => "menu"
  #   },
  #   "rightButton" => %{
  #     "type" => "button"
  #   },
  #   "onPressedLB" => %{"action" => "LB", "props" => %{}},
  #   "onPressedRB" => %{"action" => "RB"}
  # }

  @spec validate_and_build(ui()) :: {:ok, ui()} | {:error, build_errors()}
  def validate_and_build(ui) do
    ui["root"]
    |> validate_and_build_component("/root")
  end

  @spec validate_and_build_component(component(), String.t()) ::
          {:ok, component()} | {:error, build_errors()}
  def validate_and_build_component(%{"type" => comp_type} = component, prefix_path) do
    %{schema: schema, listeners: listeners, children: children, child: child} =
      JsonSchemata.get_component_path(comp_type)
      |> JsonSchemata.get_schema_map()

    with :ok <- ExComponentSchema.Validator.validate(schema, component),
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

  @spec build_listeners(component(), list(String.t())) :: {:ok, map()} | {:error, list()}
  def build_listeners(component, listeners) do
    Enum.reduce(listeners, {:ok, %{}}, fn listener, {:ok, acc} ->
      {:ok, built_listener} = build_listener(Map.get(component, listener))
      {:ok, Map.put(acc, listener, built_listener)}
    end)
  end

  @spec build_listener(map()) :: {:ok, map()}
  def build_listener(listener) do
    %{"action" => action_code} = listener
    props = Map.get(listener, "props", %{})
    listener_key = Storage.generate_listeners_key(action_code, props)
    Storage.insert(:listeners, listener_key, listener)
    {:ok, %{"code" => listener_key}}
  end

  @spec validate_and_build_child_list(component(), list(String.t()), String.t()) ::
          {:ok, map()} | {:error, build_errors()}
  def validate_and_build_child_list(component, child_list, prefix_path) do
    Enum.reduce(child_list, {%{}, []}, fn child, {acc, errors} ->
      child_path = "#{prefix_path}/#{child}"

      case validate_and_build_component(Map.get(component, child), child_path) do
        {:ok, built_component} ->
          {Map.merge(acc, %{child => built_component}), errors}

        {:error, comp_errors} ->
          tmp = Enum.map(comp_errors, &{elem(&1, 0), child_path})
          {acc, errors ++ tmp}
      end
    end)
    |> case do
      {comp, []} -> {:ok, comp}
      {_, errors} -> {:error, errors}
    end
  end

  @spec validate_and_build_children_list(component(), list(), String.t()) ::
          {:ok, map()} | {:error, build_errors()}
  def validate_and_build_children_list(component, children_list, prefix_path) do
    Enum.reduce(children_list, {%{}, []}, fn children, {acc, errors} ->
      children_path = "#{prefix_path}/#{children}"

      case validate_and_build_children(component, children, children_path) do
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
    Enum.reduce(Map.get(component, children), {[], []}, fn child, {acc, errors} ->
      children_path = "#{prefix_path}/#{children}"

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
