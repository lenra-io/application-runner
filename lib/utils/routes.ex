defmodule ApplicationRunner.Utils.Routes do
  @path_not_matching_error {:error, "Path is not matching"}

  def match_route(route, path) do
    route_parts = route |> String.trim("/") |> String.split("/")
    path_parts = path |> String.trim("/") |> String.split("/")

    if Enum.count(route_parts) == Enum.count(path_parts) do
      extract_path_params(route_parts, path_parts)
    else
      @path_not_matching_error
    end
  end

  defp extract_path_params(route_parts, path_parts) do
    Enum.zip(route_parts, path_parts)
    |> Enum.reduce_while({:ok, %{}}, fn
      {part, part}, res ->
        {:cont, res}

      {":" <> route_part, path_part}, {:ok, path_params} ->
        {:cont, {:ok, Map.put(path_params, route_part, try_parse(path_part))}}

      {_route_part, _path_part}, _path_params ->
        {:halt, @path_not_matching_error}
    end)
  end

  defp try_parse("true"), do: true
  defp try_parse("false"), do: false

  defp try_parse(value) do
    case Integer.parse(value) do
      :error -> value
      {res, _} -> res
    end
  end
end
