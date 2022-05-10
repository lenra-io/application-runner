defmodule ApplicationRunner.CacheAsyncMacro do
  @moduledoc """
    This is a using macro to create a function cache.
    Every function called with `call_function(pid, module, function_name, args)` is called only once for the same module/name/args.
    If another call_function for the same args is called then :
    - If the first call is still pending, the second call is waiting until the first one is done and the result is sent to the first and second call.
    - If the first call is done, the result is sent directly.

    ```
      use ApplicationRunner.CacheMapMacro
    ```
  """
  defmacro __using__(_opts) do
    quote do
      use GenServer

      alias ApplicationRunner.CacheMap

      def start_link(_) do
        GenServer.start_link(__MODULE__, [], [])
      end

      def cache_function(pid, module, function_name, args, key) do
        GenServer.call(pid, {:cache_function, module, function_name, args, key})
      end

      def clear(pid) do
        GenServer.cast(pid, :clear)
      end

      def init(_) do
        {:ok, cache_pid} = CacheMap.start_link(nil)
        Process.link(cache_pid)
        state = %{cache_pid: cache_pid, values: %{}}
        {:ok, state}
      end

      def handle_call({:cache_function, module, function_name, args, key}, from, state) do
        from_list = Map.get(state.values, key, [])

        case CacheMap.get(state.cache_pid, key) do
          nil ->
            CacheMap.put(state.cache_pid, key, {:pending, nil})

            {:noreply, put_in(state.values[key], [from | from_list]),
             {:continue, {:cache_function, module, function_name, args, key}}}

          {:pending, nil} ->
            {:noreply, put_in(state.values[key], [from | from_list])}

          {:done, value} ->
            {:reply, value, state}
        end
      end

      def handle_cast({:cache_function_done, key, res}, state) do
        Map.get(state.values, key, [])
        |> Enum.each(fn pid -> GenServer.reply(pid, res) end)

        {:noreply, put_in(state.values[key], [])}
      end

      def handle_cast(:clear, state) do
        CacheMap.clear(state.cache_pid)
        {:noreply, state}
      end

      def handle_continue({:cache_function, module, function_name, args, key}, state) do
        pid = self()

        spawn(fn ->
          res = apply(module, function_name, args)
          CacheMap.put(state.cache_pid, key, {:done, res})

          GenServer.cast(pid, {:cache_function_done, key, res})
        end)

        {:noreply, state}
      end
    end
  end
end
