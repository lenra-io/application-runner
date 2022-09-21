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

  @spec get_root_widget(number()) :: String.t()
  def get_root_widget(env_id) do
    GenServer.call(get_full_name(env_id), :get_root_widget)
  end

  @impl true
  def handle_call(:get_manifest, _from, state) do
    {:reply, Map.get(state, :manifest), state}
  end

  def handle_call(:get_root_widget, _from, state) do
    manifest = Map.get(state, :manifest)

    {:reply, Map.get(manifest, "rootWidget", "main"), state}
  end
end
