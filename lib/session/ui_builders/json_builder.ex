defmodule ApplicationRunner.Session.UiBuilders.JsonBuilder do
  @behaviour ApplicationRunner.Session.UiBuilders.UiBuilderAdapter

  alias ApplicationRunner.Environment
  alias ApplicationRunner.Session.RouteServer

  @type widget :: map()
  @type component :: map()

  @impl ApplicationRunner.Session.UiBuilders.UiBuilderAdapter
  def get_routes(env_id) do
    Environment.ManifestHandler.get_json_routes(env_id)
  end

  @impl ApplicationRunner.Session.UiBuilders.UiBuilderAdapter
  def build_ui(session_metadata, widget_uid) do
    with {:ok, json} <- RouteServer.fetch_widget(session_metadata, widget_uid),
         {:ok, transformed_json} <- build_listeners(session_metadata, json) do
      {:ok, transformed_json}
    end
  end

  def build_listeners(session_metadata, widget) do
    {:ok, do_build_listeners(session_metadata, widget)}
  rescue
    err -> {:error, err}
  end

  defp do_build_listeners(session_metadata, list) when is_list(list) do
    Enum.map(list, &do_build_listeners(session_metadata, &1))
  end

  defp do_build_listeners(session_metadata, %{"type" => "listener"} = listener) do
    with {:ok, built_listener} <- RouteServer.build_listener(session_metadata, listener) do
      built_listener
    else
      err -> raise err
    end
  end

  defp do_build_listeners(session_metadata, map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, do_build_listeners(session_metadata, v)} end)
    |> Map.new()
  end

  defp do_build_listeners(_session_metadata, e) do
    e
  end
end
