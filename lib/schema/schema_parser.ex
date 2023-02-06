defmodule ApplicationRunner.SchemaParser do
  @moduledoc """
  ApplicationRunner's Schema Parser
  """

  def parse(schema) do
    properties = Map.get(Map.get(schema, :schema), "properties", %{})

    case properties do
      nil ->
        {:error, "No properties found"}

      properties ->
        build_property_map(schema, properties)
    end
  end

  defp build_property_map(schema, properties) do
    Enum.reduce(
      properties,
      %{listeners: [], children: [], child: []},
      fn {key, value},
         %{
           listeners: listeners,
           children: children,
           child: child
         } = acc ->
        case parse_property(schema, key, value) do
          {:listener, key} -> Map.put(acc, :listeners, [key | listeners])
          {:children, key} -> Map.put(acc, :children, [key | children])
          {:child, key} -> Map.put(acc, :child, [key | child])
          _ -> acc
        end
      end
    )
  end

  def parse_property(schema, key, value) do
    IO.inspect({:parse_property, schema, key, value})

    case value do
      %{"$ref" => ref} ->
        fragment = schema[ref]
        parse_property(schema, key, fragment)

      %{"type" => "listener"} ->
        {:listener, key}

      %{"type" => "component"} ->
        {:child, key}

      %{"type" => "array", "items" => %{"type" => "component"}} ->
        {:children, key}

      _ ->
        :none
    end
  end
end
