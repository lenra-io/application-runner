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

defmodule ApplicationRunner.MyCacheAsync do
  use ApplicationRunner.CacheAsyncMacro
end

defmodule ApplicationRunner.CacheMapTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.CacheMapTest` module
  """

  doctest ApplicationRunner.CacheMap

  alias ApplicationRunner.MyCacheAsync

  test "Can create cache_async" do
    {:ok, cache_pid} = GenServer.start_link(MyCacheAsync, nil)

    tasks = [
      Task.async(fn ->
        res = MyCacheAsync.cache_function(cache_pid, TestModule, :foo, [], "foo")
        {res, System.system_time()}
      end),
      Task.async(fn ->
        res = MyCacheAsync.cache_function(cache_pid, TestModule, :bar, [], "bar")
        {res, System.system_time()}
      end),
      Task.async(fn ->
        res = MyCacheAsync.cache_function(cache_pid, TestModule, :foo, [], "foo")
        {res, System.system_time()}
      end)
    ]

    [{r1, t1}, {r2, t2}, {r3, t3}] = Task.await_many(tasks)

    assert r1 == :ok
    assert r2 == 42
    assert r3 == :ok

    assert t2 < t1
    offset = System.convert_time_unit(1, :millisecond, :native)
    assert t1 >= t3 - offset
    assert t2 <= t3 + offset
  end

  test "Stress test cache_async" do
    {:ok, cache_pid} = GenServer.start_link(MyCacheAsync, nil)

    0..200
    |> Enum.to_list()
    |> Enum.map(fn _ ->
      Process.sleep(10)

      Task.async(fn ->
        res = MyCacheAsync.cache_function(cache_pid, TestModule, :baz, [], "baz")
        res
      end)
    end)
    |> Task.await_many()
    |> Enum.map(fn r ->
      assert r == :ok
    end)
  end
end
