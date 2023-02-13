defmodule ApplicationRunner.SchemaParser do
  @moduledoc """
  ApplicationRunner's Schema Parser
  """

  def parse(root_schema, schema) do
    properties = Map.get(schema, "properties", %{})

    case properties do
      nil ->
        {:error, "No properties found"}

      properties ->
        build_property_map(root_schema, schema, properties)
    end
  end

  defp build_property_map(root_schema, schema, properties) do
    Enum.reduce(
      properties,
      %{listeners: [], children: [], child: []},
      fn {key, value},
         %{
           listeners: listeners,
           children: children,
           child: child
         } = acc ->
        case parse_property(root_schema, schema, key, value) do
          {:listener, key} -> Map.put(acc, :listeners, [key | listeners])
          {:children, key} -> Map.put(acc, :children, [key | children])
          {:child, key} -> Map.put(acc, :child, [key | child])
          _ -> acc
        end
      end
    )
  end

  def parse_property(root_schema, schema, key, value) do
    case value do
      %{"$ref" => ref} ->
        fragment = get_in(root_schema.refs, ref)
        parse_property(root_schema, schema, key, fragment)

      %{"type" => "listener"} ->
        {:listener, key}

      %{"$ref" => _ref} ->
        {:child, key}

      %{"type" => "array", "items" => %{"$ref" => _ref}} ->
        {:children, key}

      _ ->
        :none
    end
  end
end
