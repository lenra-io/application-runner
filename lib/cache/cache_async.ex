defmodule ApplicationRunner.CacheAsync do
  use GenServer

  alias ApplicationRunner.CacheMap

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def call_function(pid, cache_pid, module, function_name, args) do
    GenServer.call(pid, {:call_function, cache_pid, module, function_name, args})
  end

  def init(_) do
    state = %{ }
    {:ok, state}
  end

  def handle_call({:call_function, cache_pid, module, function_name, args}, from, state) do
    key = {module, function_name, args}
    from_list = Map.get(state, key, [])

    case CacheMap.get(cache_pid, key) do
      nil ->
        CacheMap.put(cache_pid, key, {:pending, nil})
        {:noreply, Map.put(state, key, [from | from_list]), {:continue, {:call_function, cache_pid, module, function_name, args}}}
      {:pending, nil} -> {:noreply, Map.put(state, key, [from | from_list])}
      {:done, value} -> {:reply, value, state}
    end
  end

  def handle_cast({:call_function_done, key, res}, state) do
    Map.get(state, key, [])
      |> Enum.each(fn pid -> GenServer.reply(pid, res) end)
    {:noreply, Map.put(state, key, [])}
  end

  def handle_continue({:call_function, cache_pid, module, function_name, args}, state) do
    key = {module, function_name, args}
    pid = self()
    spawn(fn ->
      res = apply(module, function_name, args)
      CacheMap.put(cache_pid, key, {:done, res})

      GenServer.cast(pid, {:call_function_done, key, res})
    end)

    {:noreply, state}
  end
end
