defmodule ApplicationRunner.Environments.ManifestHandler do
  @moduledoc """
    Environments.ManifestHandler is a genserver that get and cache manifest for one app
  """
  use GenServer

  alias ApplicationRunner.{ApplicationServices, Environments}

  def start_link(opts) do
    with {:ok, pid} <-
           GenServer.start_link(__MODULE__, opts) do
      pid
    end
  end

  @impl true
  def init(opts) do
    IO.inspect(opts)
    state = Keyword.fetch!(opts, :env_state)

    IO.inspect(state)

    case ApplicationServices.fetch_manifest(state) do
      {:ok, manifest} ->
        {:ok, %{manifest: manifest}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @spec get_manifest(number()) :: map()
  def get_manifest(env_id) do
    with pid when is_pid(pid) <- Environments.Supervisor.fetch_module_pid!(env_id, __MODULE__) do
      GenServer.call(pid, :get_manifest)
    end
  end

  @impl true
  def handle_call(:get_manifest, _from, state) do
    {:reply, Map.get(state, :manifest), state}
  end
end
