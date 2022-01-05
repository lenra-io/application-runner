defmodule ApplicationRunner.EnvManagersTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.EnvManagers` module
  """

  alias ApplicationRunner.EnvManagers

  setup do
    start_supervised(EnvManagers)

    :ok
  end

  test "Can start one Env" do
    assert {:ok, _} = EnvManagers.start_env(make_ref(), 1, "app")
  end

  test "Can start multiple Envs" do
    1..10
    |> Enum.to_list()
    |> Enum.each(fn _ ->
      assert {:ok, _} = EnvManagers.start_env(make_ref(), 1, "app")
    end)
  end

  test "Can start one Env and get it after" do
    env_id = make_ref()
    assert {:error, :env_not_started} = EnvManagers.fetch_env_manager_pid(env_id)
    assert {:ok, pid} = EnvManagers.start_env(env_id, 1, "app")
    assert {:ok, ^pid} = EnvManagers.fetch_env_manager_pid(env_id)
  end

  test "Cannot start same env twice" do
    env_id = make_ref()
    assert {:ok, pid} = EnvManagers.start_env(env_id, 1, "app")
    assert {:error, {:already_started, ^pid}} = EnvManagers.start_env(env_id, 1, "app")
  end
end
