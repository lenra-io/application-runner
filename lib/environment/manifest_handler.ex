defmodule ApplicationRunner.Environment.ManifestHandler do
  @moduledoc """
    Environment.ManifestHandler is a genserver that gets and caches the manifest of an app
  """
  use GenServer
  use SwarmNamed

  alias ApplicationRunner.{ApplicationServices, Environment}

  def start_link(%Environment.Metadata{} = env_metadata) do
    with {:ok, pid} <-
           GenServer.start_link(__MODULE__, env_metadata, name: get_full_name(env_metadata.env_id)) do
      pid
    end
  end

  @impl true
  def init(env_metadata) do
    case ApplicationServices.fetch_manifest(env_metadata) do
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

  @impl true
  def handle_call(:get_manifest, _from, state) do
    {:reply, Map.get(state, :manifest), state}
  end
end
