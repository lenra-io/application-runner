defmodule ApplicationRunner.CacheMap do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def put(pid, key, value) do
    GenServer.cast(pid, {:put, key, value})
  end

  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end

  def delete(pid, key) do
    GenServer.cast(pid, {:expire, key})
  end


  def init(_) do
    state = %{}
    {:ok, state}
  end

  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end

  def handle_cast({:expire, key}, state) do
    {:noreply, Map.delete(state, key)}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

end
