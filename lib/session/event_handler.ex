defmodule ApplicationRunner.EventHandler do
  @moduledoc """
    This EventHandler genserver handle and run all the listener events.
  """
  use GenServer

  alias ApplicationRunner.AdapterHandler

  #########
  ## API ##
  #########
  def send_event(handler_pid, state, action, props, event) do
    GenServer.cast(handler_pid, {:send_event, state, action, props, event})
  end

  def subscribe(handler_pid) do
    GenServer.call(handler_pid, :subscribe)
  end

  ###############
  ## Callbacks ##
  ###############

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], [])
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:send_event, state, action, props, event}, pids) do
    res = AdapterHandler.run_listener(state, action, props, event)

    Enum.each(pids, fn pid ->
      send(pid, {:event_finished, action, res})
    end)

    {:noreply, pids}
  end

  @impl true
  def handle_call(:subscribe, {pid, _}, pids) do
    {:reply, :ok, [pid | pids]}
  end
end
