defmodule ApplicationRunner.Environment.ManifestHandler do
  @moduledoc """
    Environment.ManifestHandler is a genserver that gets and caches the manifest of an app
  """
  use GenServer
  use SwarmNamed

  alias ApplicationRunner.ApplicationServices

  require Logger

  def start_link(opts) do
    Logger.debug("#{__MODULE__} start_link with #{opts}")
    Logger.info("Start #{__MODULE__}")
    env_id = Keyword.fetch!(opts, :env_id)
    GenServer.start_link(__MODULE__, opts, name: get_full_name(env_id))
  end

  @impl true
  def init(opts) do
    Logger.debug("#{__MODULE__} init with #{opts}")

    function_name = Keyword.fetch!(opts, :function_name)

    res =
      case ApplicationServices.fetch_manifest(function_name) do
        {:ok, manifest} ->
          {:ok, %{manifest: manifest}}

        {:error, reason} ->
          {:stop, reason}
      end

    Logger.debug("#{__MODULE__} init exit with #{opts}")
    res
  end

  @doc """
   Return the Manifest for the given env_id
  """
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
    Logger.debug("#{__MODULE__} handle call for #{inspect(:get_manifest)} with #{state}")

    {:reply, Map.get(state, :manifest), state}
  end

  @default_route %{"/" => %{"type" => "view", "name" => "main"}}
  def handle_call(:get_lenra_routes, _from, state) do
    Logger.debug("#{__MODULE__} handle call for #{inspect(:get_lenra_routes)} with #{state}")

    manifest = Map.get(state, :manifest)

    {:reply, Map.get(manifest, "lenraRoutes", @default_route), state}
  end

  def handle_call(:get_json_routes, _from, state) do
    Logger.debug("#{__MODULE__} handle call for #{inspect(:get_json_routes)} with #{state}")

    manifest = Map.get(state, :manifest)

    {:reply, Map.get(manifest, "jsonRoutes", @default_route), state}
  end
end
