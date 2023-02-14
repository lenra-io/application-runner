defmodule ApplicationRunner.Environment.ManifestHandler do
  @moduledoc """
    Environment.ManifestHandler is a genserver that gets and caches the manifest of an app
  """
  use GenServer
  use SwarmNamed

  alias ApplicationRunner.ApplicationServices

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    GenServer.start_link(__MODULE__, opts, name: get_full_name(env_id))
  end

  @impl true
  def init(opts) do
    function_name = Keyword.fetch!(opts, :function_name)

    case ApplicationServices.fetch_manifest(function_name) do
      {:ok, manifest} ->
        {:ok, %{manifest: manifest}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @spec get_manifest(number()) :: map()
  def get_manifest(env_id) do
    GenServer.call(get_full_name(env_id), :get_manifest)
  end

  @spec get_lenra_routes(number()) :: map()
  def get_lenra_routes(env_id) do
    GenServer.call(get_full_name(env_id), :get_lenra_routes)
  end

  @spec get_json_routes(number()) :: map()
  def get_json_routes(env_id) do
    GenServer.call(get_full_name(env_id), :get_json_routes)
  end

  @impl true
  def handle_call(:get_manifest, _from, state) do
    {:reply, Map.get(state, :manifest), state}
  end

  @default_routes [%{"/" => %{"type" => "view", "name" => "main"}}]
  def handle_call(:get_lenra_routes, _from, state) do
    manifest = Map.get(state, :manifest)

    {:reply, get_route(manifest), state}
  end

  @default_json_route %{"/" => %{"type" => "view", "name" => "main"}}
  def handle_call(:get_json_routes, _from, state) do
    manifest = Map.get(state, :manifest)

    {:reply, Map.get(manifest, "jsonRoutes", @default_json_route), state}
  end

  defp get_route(%{"rootView" => rootView}) do
    %{"/" => %{"type" => "view", "name" => rootView}}
  end

  defp get_route(manifest) do
    Map.get(manifest, "lenraRoutes", @default_routes)
  end
end
