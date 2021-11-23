defmodule TestModule do
  def foo do
    Process.sleep(50)
    :ok
  end

  def bar do
    42
  end

  def baz do
    Process.sleep(1000)
    :ok
  end
end

defmodule ApplicationRunner.CacheMapTest do
  use ExUnit.Case, async: true

  @moduledoc """
    Test the `ApplicationRunner.CacheMapTest` module
  """

  doctest ApplicationRunner.CacheMap

  test "Can create cache_map" do
    {:ok, cache} = GenServer.start_link(ApplicationRunner.CacheMap, nil)

    :ok = ApplicationRunner.CacheMap.put(cache, "foo", "bar")
    assert ApplicationRunner.CacheMap.get(cache, "foo") == "bar"

  end



  test "Can create cache_async" do
    {:ok, cache_map} = GenServer.start_link(ApplicationRunner.CacheMap, nil)
    {:ok, cache_async} = GenServer.start_link(ApplicationRunner.CacheAsync, nil)

    tasks = [Task.async(fn ->
      res = ApplicationRunner.CacheAsync.call_function(cache_async, cache_map, TestModule, :foo, [])
      IO.puts("T1")
      {res, System.system_time()}
    end),
    Task.async(fn ->
      res = ApplicationRunner.CacheAsync.call_function(cache_async, cache_map, TestModule, :bar, [])
      IO.puts("T2")
      {res, System.system_time()}
    end),
    Task.async(fn ->
      res = ApplicationRunner.CacheAsync.call_function(cache_async, cache_map, TestModule, :foo, [])
      IO.puts("T3")
      {res, System.system_time()}
    end)]

    [{r1, t1}, {r2, t2}, {r3, t3}] = Task.await_many(tasks)

    assert r1 == :ok
    assert r2 == 42
    assert r3 == :ok

    assert t2 < t1
    offset = System.convert_time_unit(1, :millisecond, :native)
    assert t1 >= t3-offset
    assert t2 <= t3+offset

  end

  test "Stress test cache_async" do
    {:ok, cache_map} = GenServer.start_link(ApplicationRunner.CacheMap, nil)
    {:ok, cache_async} = GenServer.start_link(ApplicationRunner.CacheAsync, nil)

    0..200
      |>Enum.to_list()
      |>Enum.map(fn _ ->
        Process.sleep(10)
        Task.async(fn ->
        res = ApplicationRunner.CacheAsync.call_function(cache_async, cache_map, TestModule, :baz, [])
        res
      end)end)
      |> Task.await_many
      |> Enum.map(fn r ->
        assert r == :ok
      end)
  end
end
