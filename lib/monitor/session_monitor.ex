defmodule ApplicationRunner.Monitor.SessionMonitor do
  @moduledoc """
    The app_channel monitor which monitors the time spent by the client on an app
  """

  use GenServer
  use SwarmNamed

  alias ApplicationRunner.Telemetry

  def monitor(pid, metadata) do
    GenServer.call({:via, :swarm, __MODULE__}, {:monitor, pid, metadata})
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: {:via, :swarm, __MODULE__})
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:monitor, pid, metadata}, _from, state) do
    Process.monitor(pid)

    start_time = Map.get(metadata, :start_time)

    {:reply, :ok, Map.put(state, pid, {start_time, metadata})}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {{start_time, metadata}, new_state} = Map.pop(state, pid)

    Telemetry.stop(:app_session, start_time, metadata)

    {:noreply, new_state}
  end

  def handle_info({:swarm, :die}, _state) do
    {:error, {:already_started, Swarm.whereis_name({:via, :swarm, __MODULE__})}}
  end
end
