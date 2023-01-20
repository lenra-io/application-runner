# UNUSED Module

# defmodule ApplicationRunner.Cache.Macro do
#   @moduledoc """
#     This is a using macro to create a simple key/value in-memory cache.

#     ```
#       use ApplicationRunner.Cache.Macro
#     ```
#   """
#   defmacro __using__(_opts) do
#     quote generated: true, location: :keep do
#       use GenServer

#       def start_link(_) do
#         GenServer.start_link(__MODULE__, [], [])
#       end

#       @spec put(pid(), term(), term()) :: :ok
#       def put(pid, key, value) do
#         GenServer.cast(pid, {:put, key, value})
#       end

#       @spec get(pid(), term()) :: term() | nil
#       def get(pid, key) do
#         GenServer.call(pid, {:get, key})
#       end

#       @spec delete(pid(), term()) :: :ok
#       def delete(pid, key) do
#         GenServer.cast(pid, {:delete, key})
#       end

#       @spec clear(pid()) :: :ok
#       def clear(pid) do
#         GenServer.cast(pid, :clear)
#       end

#       def init(_) do
#         state = %{}
#         {:ok, state}
#       end

#       def handle_cast({:put, key, value}, state) do
#         {:noreply, Map.put(state, key, value)}
#       end

#       def handle_cast({:delete, key}, state) do
#         {:noreply, Map.delete(state, key)}
#       end

#       def handle_cast(:clear, state) do
#         {:noreply, %{}}
#       end

#       def handle_call({:get, key}, _from, state) do
#         {:reply, Map.get(state, key), state}
#       end
#     end
#   end
# end
