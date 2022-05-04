defmodule ApplicationRunner.EnvManagerTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.AppManager` module
  """

  alias ApplicationRunner.{
    ApplicationRunnerAdapter,
    EnvManager,
    EnvManagers,
    EnvSupervisor,
    MockGenServer
  }

  setup do
    start_supervised(EnvManagers)
    :ok
  end

  test "Can EnvManager supervisor should exist and have the MockGenServer." do
    assert {:ok, pid} = EnvManagers.start_env(make_ref(), %{})
    env_state = :sys.get_state(pid)

    assert is_pid(EnvSupervisor.fetch_module_pid!(env_state.env_supervisor_pid, MockGenServer))
  end

  test "Can EnvManager supervisor should not have the NotExistGenServer" do
    assert {:ok, pid} = EnvManagers.start_env(make_ref(), %{})
    env_state = :sys.get_state(pid)

    assert_raise(
      RuntimeError,
      "No such Module in EnvSupervisor. This should not happen.",
      fn -> EnvSupervisor.fetch_module_pid!(env_state.env_supervisor_pid, NotExistGenServer) end
    )
  end

  test "get_manifest call the get_manifest of the adapter" do
    env_id = make_ref()
    assert {:ok, _pid} = EnvManagers.start_env(env_id, %{})

    assert ApplicationRunnerAdapter.manifest_const() == EnvManager.get_manifest(env_id)
  end

  test "EnvManager should stop if EnvSupervisor is killed." do
    assert {:ok, pid} = EnvManagers.start_env(make_ref(), %{})
    env_state = :sys.get_state(pid)
    env_supervisor_pid = Map.fetch!(env_state, :env_supervisor_pid)
    assert Process.alive?(env_supervisor_pid)
    assert Process.alive?(pid)

    Process.exit(env_supervisor_pid, :kill)
    assert not Process.alive?(env_supervisor_pid)
    assert not Process.alive?(pid)
  end

  test "EnvManager should exist in Swarm group :envs" do
    assert {:ok, pid} = EnvManagers.start_env(make_ref(), %{})
    assert Enum.member?(Swarm.members(:envs), pid)
  end
end
